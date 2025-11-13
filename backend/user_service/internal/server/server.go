package server

import (
	"fmt"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
)

// Server wraps the Gin engine for the user-service.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// New wires repositories, handlers, and middleware for the user-service.
func New(cfg *config.Config, db *gorm.DB, driverProvisioner handlers.DriverProvisioner) (*Server, error) {
	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.Auth(cfg.JWTSecret))

	handlers.RegisterHealth(router)

	userRepo := domain.NewUserRepository(db)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	authHandler := handlers.NewAuthHandler(cfg, userRepo, notificationRepo, driverProvisioner)

	router.POST("/auth/register", authHandler.Register)
	router.POST("/auth/login", authHandler.Login)
	router.GET("/auth/me", authHandler.Me)
	router.PATCH("/users/me", authHandler.UpdateMe)
	router.POST("/v1/drivers/register", authHandler.RegisterDriver)

	handlers.RegisterNotificationRoutes(router, notificationRepo)

	walletRepo := dbrepo.NewWalletRepository(db)
	savedRepo := dbrepo.NewSavedPlaceRepository(db)
	promoRepo := dbrepo.NewPromotionRepository(db)
	newsRepo := dbrepo.NewNewsRepository(db)
	homeService := domain.NewHomeService(walletRepo, savedRepo, promoRepo, newsRepo)
	handlers.RegisterHomeRoutes(router, homeService)

	return &Server{engine: router, cfg: cfg}, nil
}

// Run starts the HTTP server.
func (s *Server) Run() error {
	addr := fmt.Sprintf(":%s", s.cfg.Port)
	return s.engine.Run(addr)
}
