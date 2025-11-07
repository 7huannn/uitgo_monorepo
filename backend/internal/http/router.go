package http

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
)

// Server wraps the Gin engine and dependencies.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// NewServer configures a Gin engine with routes and middleware.
func NewServer(cfg *config.Config, db *gorm.DB) (*Server, error) {
	router := gin.New()
	if err := router.SetTrustedProxies([]string{"127.0.0.1"}); err != nil {
		log.Printf("warn: unable to set trusted proxies: %v", err)
	}

	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.Auth(cfg.JWTSecret))

	tripRepo := dbrepo.NewTripRepository(db)
	driverRepo := dbrepo.NewDriverRepository(db)
	assignmentRepo := dbrepo.NewTripAssignmentRepository(db)
	tripService := domain.NewTripService(tripRepo)
	driverService := domain.NewDriverService(driverRepo, assignmentRepo, tripRepo)
	hubManager := handlers.NewHubManager(tripService, driverRepo)
	userRepo := domain.NewUserRepository(db)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	authHandler := handlers.NewAuthHandler(cfg, userRepo, notificationRepo, driverService)
	walletRepo := dbrepo.NewWalletRepository(db)
	savedPlaceRepo := dbrepo.NewSavedPlaceRepository(db)
	promotionRepo := dbrepo.NewPromotionRepository(db)
	newsRepo := dbrepo.NewNewsRepository(db)
	homeService := domain.NewHomeService(walletRepo, savedPlaceRepo, promotionRepo, newsRepo)

	handlers.RegisterHealth(router)
	router.POST("/auth/register", authHandler.Register)
	router.POST("/auth/login", authHandler.Login)
	router.GET("/auth/me", authHandler.Me)
	router.PATCH("/users/me", authHandler.UpdateMe)
	router.POST("/v1/drivers/register", authHandler.RegisterDriver)
	handlers.RegisterDriverRoutes(router, driverService)
	handlers.RegisterTripRoutes(router, tripService, driverService, hubManager)
	handlers.RegisterNotificationRoutes(router, notificationRepo)
	handlers.RegisterHomeRoutes(router, homeService)

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
