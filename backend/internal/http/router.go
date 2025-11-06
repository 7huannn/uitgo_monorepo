package http

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

// Server wraps the Gin engine and dependencies.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// NewServer configures a Gin engine with routes and middleware.
func NewServer(cfg *config.Config, db *gorm.DB) (*Server, error) {
	router := gin.New()

	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.Auth())

	tripRepo := dbrepo.NewTripRepository(db)
	tripService := domain.NewTripService(tripRepo)
	hubManager := handlers.NewHubManager(tripService)

	handlers.RegisterHealth(router)
	handlers.RegisterTripRoutes(router, tripService, hubManager)

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
