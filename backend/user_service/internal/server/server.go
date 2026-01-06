package server

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"uitgo/backend/internal/cache"
	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
	"uitgo/backend/internal/notification"
	"uitgo/backend/internal/observability"
)

// Server wraps the Gin engine for the user-service.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// New wires repositories, handlers, and middleware for the user-service.
func New(cfg *config.Config, db *gorm.DB, driverProvisioner handlers.DriverProvisioner) (*Server, error) {
	const serviceName = "user-service"
	router := gin.New()
	gin.DisableConsoleColor()
	router.Use(otelgin.Middleware(serviceName))
	router.Use(middleware.JSONLogger(serviceName))
	router.Use(observability.GinMiddleware())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.Auth(cfg.JWTSecret, cfg.InternalAPIKey))

	metrics := middleware.NewHTTPMetrics(serviceName, cfg.PrometheusEnabled)
	router.Use(metrics.Handler())

	auditRepo := domain.NewAuditLogRepository(db)
	router.Use(middleware.AuditLogger(auditRepo))

	handlers.RegisterHealth(router)
	authLimiter := middleware.NewTokenBucketRateLimiter(10, time.Minute)
	userRepo := domain.NewUserRepository(db)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	deviceTokenRepo := dbrepo.NewDeviceTokenRepository(db)
	pushSender, err := notification.BuildSenderFromConfig(context.Background(), cfg)
	if err != nil {
		fmt.Printf("warn: unable to initialize FCM: %v\n", err)
	}
	notificationSvc := notification.NewService(notificationRepo, deviceTokenRepo, pushSender)
	refreshRepo := domain.NewRefreshTokenRepository(db)
	authHandler, err := handlers.NewAuthHandler(cfg, userRepo, notificationRepo, driverProvisioner, refreshRepo)
	if err != nil {
		return nil, err
	}
	seedAdminUser(context.Background(), cfg, userRepo)

	router.POST("/auth/register", authLimiter.Middleware("auth_register"), authHandler.Register)
	router.POST("/auth/login", authLimiter.Middleware("auth_login"), authHandler.Login)
	router.POST("/auth/refresh", authLimiter.Middleware("auth_refresh"), authHandler.Refresh)
	router.GET("/auth/me", authHandler.Me)
	router.PATCH("/users/me", authHandler.UpdateMe)
	router.POST("/v1/drivers/register", authHandler.RegisterDriver)

	adminGroup := router.Group("/admin")
	adminGroup.Use(middleware.RequireRoles("admin"))
	adminGroup.GET("/me", authHandler.Me)

	handlers.RegisterNotificationRoutes(router, notificationRepo, notificationSvc)

	walletRepo := dbrepo.NewWalletRepository(db)
	walletService := domain.NewWalletService(walletRepo)
	savedRepo := dbrepo.NewSavedPlaceRepository(db)
	promoRepo := dbrepo.NewPromotionRepository(db)
	newsRepo := dbrepo.NewNewsRepository(db)

	if cfg.HomeCacheTTL > 0 {
		homeCache, err := cache.NewHomeCache(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB, cfg.HomeCacheTTL)
		if err != nil {
			log.Printf("warn: home cache disabled: %v", err)
		} else if homeCache != nil {
			promoRepo = cache.NewCachedPromotionRepository(promoRepo, homeCache)
			newsRepo = cache.NewCachedNewsRepository(newsRepo, homeCache)
		}
	}
	homeService := domain.NewHomeService(walletRepo, savedRepo, promoRepo, newsRepo)
	handlers.RegisterWalletRoutes(router, walletService)
	handlers.RegisterHomeRoutes(router, homeService)

	internal := router.Group("/internal")
	internal.Use(middleware.InternalOnly(cfg.InternalAPIKey))
	handlers.RegisterWalletInternalRoutes(internal, walletService)

	metrics.Expose(router)

	return &Server{engine: router, cfg: cfg}, nil
}

// Run starts the HTTP server.
func (s *Server) Run() error {
	addr := fmt.Sprintf(":%s", s.cfg.Port)
	return s.engine.Run(addr)
}

func seedAdminUser(ctx context.Context, cfg *config.Config, repo domain.UserRepository) {
	if repo == nil {
		return
	}
	email := strings.ToLower(strings.TrimSpace(cfg.AdminEmail))
	password := strings.TrimSpace(cfg.AdminPassword)
	name := strings.TrimSpace(cfg.AdminName)
	if name == "" {
		name = "UITGo Admin"
	}
	// SECURITY: Do not use hardcoded fallback credentials
	// Admin credentials MUST be provided via ADMIN_EMAIL and ADMIN_PASSWORD env vars
	if email == "" || password == "" {
		log.Printf("admin seed: skipping - ADMIN_EMAIL and ADMIN_PASSWORD must be set via environment variables")
		return
	}
	// SECURITY: Enforce minimum password length
	if len(password) < 12 {
		log.Printf("admin seed: skipping - ADMIN_PASSWORD must be at least 12 characters")
		return
	}

	existing, err := repo.FindByEmail(ctx, email)
	if err == nil && existing != nil {
		if strings.ToLower(existing.Role) != "admin" {
			log.Printf("admin seed: user %s exists with role %s (expected admin), updating role", email, existing.Role)
			role := "admin"
			_, _ = repo.UpdateRoleAndStatus(ctx, existing.ID, &role, nil)
		}
		return
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		log.Printf("admin seed: unable to check existing user: %v", err)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("admin seed: failed to hash password: %v", err)
		return
	}
	user := &domain.User{
		Name:         name,
		Email:        email,
		PasswordHash: string(hash),
		Role:         "admin",
	}
	if err := repo.Create(ctx, user); err != nil {
		log.Printf("admin seed: failed to create admin user: %v", err)
		return
	}
	log.Printf("admin seed: ensured admin account %s", email)
}
