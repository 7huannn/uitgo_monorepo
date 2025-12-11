package http

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
	"uitgo/backend/internal/notification"
	"uitgo/backend/internal/observability"
	"uitgo/backend/internal/routing"
)

// Server wraps the Gin engine and dependencies.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// NewServer configures a Gin engine with routes and middleware.
func NewServer(cfg *config.Config, db *gorm.DB) (*Server, error) {
	const serviceName = "api"
	router := gin.New()
	gin.DisableConsoleColor()
	if err := router.SetTrustedProxies([]string{"127.0.0.1"}); err != nil {
		log.Printf("warn: unable to set trusted proxies: %v", err)
	}

	router.Use(middleware.JSONLogger(serviceName))
	router.Use(observability.GinMiddleware())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.Auth(cfg.JWTSecret, cfg.InternalAPIKey))

	metrics := middleware.NewHTTPMetrics(serviceName, cfg.PrometheusEnabled)
	router.Use(metrics.Handler())

	auditRepo := domain.NewAuditLogRepository(db)
	router.Use(middleware.AuditLogger(auditRepo))

	walletRepo := dbrepo.NewWalletRepository(db)
	walletService := domain.NewWalletService(walletRepo)
	tripRepo := dbrepo.NewTripRepository(db)
	driverRepo := dbrepo.NewDriverRepository(db)
	assignmentRepo := dbrepo.NewTripAssignmentRepository(db)

	deviceTokenRepo := dbrepo.NewDeviceTokenRepository(db)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	pushSender, err := notification.BuildSenderFromConfig(context.Background(), cfg)
	if err != nil {
		log.Printf("warn: unable to initialize FCM: %v", err)
	}
	notificationSvc := notification.NewService(notificationRepo, deviceTokenRepo, pushSender)

	tripService := domain.NewTripService(tripRepo, walletService, notificationSvc)
	driverService := domain.NewDriverService(driverRepo, assignmentRepo, tripRepo, notificationSvc, nil)
	hubManager := handlers.NewHubManager(tripService, driverRepo)
	userRepo := domain.NewUserRepository(db)
	refreshRepo := domain.NewRefreshTokenRepository(db)
	authHandler, err := handlers.NewAuthHandler(cfg, userRepo, notificationRepo, driverService, refreshRepo)
	if err != nil {
		return nil, err
	}
	seedAdminUser(context.Background(), cfg, userRepo)
	savedPlaceRepo := dbrepo.NewSavedPlaceRepository(db)
	promotionRepo := dbrepo.NewPromotionRepository(db)
	newsRepo := dbrepo.NewNewsRepository(db)
	homeService := domain.NewHomeService(walletRepo, savedPlaceRepo, promotionRepo, newsRepo)
	routeProvider := routing.NewClient(cfg.RoutingBaseURL, 8*time.Second, 5*time.Minute)

	handlers.RegisterHealth(router)
	handlers.RegisterRouteRoutes(router, routeProvider)
	debugGroup := router.Group("/internal/debug")
	debugGroup.Use(middleware.InternalOnly(cfg.InternalAPIKey))
	debugGroup.GET("/panic", func(c *gin.Context) {
		panic("intentional panic")
	})
	authLimiter := middleware.NewTokenBucketRateLimiter(10, time.Minute)
	tripLimiter := middleware.NewTokenBucketRateLimiter(10, time.Minute)
	router.POST("/auth/register", authLimiter.Middleware("auth_register"), authHandler.Register)
	router.POST("/auth/login", authLimiter.Middleware("auth_login"), authHandler.Login)
	router.POST("/auth/refresh", authLimiter.Middleware("auth_refresh"), authHandler.Refresh)
	router.GET("/auth/me", authHandler.Me)
	router.PATCH("/users/me", authHandler.UpdateMe)
	router.POST("/v1/drivers/register", authHandler.RegisterDriver)
	adminGroup := router.Group("/admin")
	adminGroup.Use(middleware.RequireRoles("admin"))
	adminGroup.GET("/me", authHandler.Me)
	handlers.RegisterAdminRoutes(adminGroup, userRepo, promotionRepo)
	handlers.RegisterDriverRoutes(router, driverService)
	handlers.RegisterTripRoutes(router, tripService, driverService, hubManager, nil, tripLimiter.Middleware("trip_create"))
	handlers.RegisterNotificationRoutes(router, notificationRepo, notificationSvc)
	handlers.RegisterWalletRoutes(router, walletService)
	handlers.RegisterHomeRoutes(router, homeService)

	metrics.Expose(router)

	return &Server{
		engine: router,
		cfg:    cfg,
	}, nil
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
	if email == "" || password == "" {
		// fallback dev admin
		email = "admin@example.com"
		password = "admin123"
		log.Printf("admin seed: using default dev admin credentials (%s)", email)
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
