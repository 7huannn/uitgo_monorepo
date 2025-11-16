package server

import (
	"context"
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

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

	router.POST("/auth/register", authLimiter.Middleware("auth_register"), authHandler.Register)
	router.POST("/auth/login", authLimiter.Middleware("auth_login"), authHandler.Login)
	router.POST("/auth/refresh", authLimiter.Middleware("auth_refresh"), authHandler.Refresh)
	router.GET("/auth/me", authHandler.Me)
	router.PATCH("/users/me", authHandler.UpdateMe)
	router.POST("/v1/drivers/register", authHandler.RegisterDriver)

	handlers.RegisterNotificationRoutes(router, notificationRepo, notificationSvc)

	walletRepo := dbrepo.NewWalletRepository(db)
	walletService := domain.NewWalletService(walletRepo)
	savedRepo := dbrepo.NewSavedPlaceRepository(db)
	promoRepo := dbrepo.NewPromotionRepository(db)
	newsRepo := dbrepo.NewNewsRepository(db)
	homeService := domain.NewHomeService(walletRepo, savedRepo, promoRepo, newsRepo)
	handlers.RegisterWalletRoutes(router, walletService)
	handlers.RegisterHomeRoutes(router, homeService)

	metrics.Expose(router)

	return &Server{engine: router, cfg: cfg}, nil
}

// Run starts the HTTP server.
func (s *Server) Run() error {
	addr := fmt.Sprintf(":%s", s.cfg.Port)
	return s.engine.Run(addr)
}
