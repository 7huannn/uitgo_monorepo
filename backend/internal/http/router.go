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

	userRepo := domain.NewUserRepository(db)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	authHandler := handlers.NewAuthHandler(cfg, userRepo, notificationRepo)
	tripRepo := dbrepo.NewTripRepository(db)
	tripService := domain.NewTripService(tripRepo)
	hubManager := handlers.NewHubManager(tripService)

	handlers.RegisterHealth(router)
	router.POST("/auth/register", authHandler.Register)
	router.POST("/auth/login", authHandler.Login)
	router.GET("/auth/me", authHandler.Me)
	router.PATCH("/users/me", authHandler.UpdateMe)
	handlers.RegisterTripRoutes(router, tripService, hubManager)
	handlers.RegisterNotificationRoutes(router, notificationRepo)

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
