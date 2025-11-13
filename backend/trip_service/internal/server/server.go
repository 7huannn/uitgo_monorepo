package server

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
)

// Server represents the trip-service HTTP server.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// New constructs the HTTP server with trip routes and internal hooks.
func New(cfg *config.Config, db *gorm.DB, driverLocations handlers.DriverLocationWriter) (*Server, error) {
	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.Auth(cfg.JWTSecret))

	handlers.RegisterHealth(router)

	tripRepo := dbrepo.NewTripRepository(db)
	tripService := domain.NewTripService(tripRepo)
	hubManager := handlers.NewHubManager(tripService, driverLocations)

	handlers.RegisterTripRoutes(router, tripService, nil, hubManager)
	registerInternalRoutes(router, cfg, tripService, hubManager)

	return &Server{engine: router, cfg: cfg}, nil
}

// Run starts serving HTTP requests.
func (s *Server) Run() error {
	addr := fmt.Sprintf(":%s", s.cfg.Port)
	return s.engine.Run(addr)
}

func registerInternalRoutes(router gin.IRouter, cfg *config.Config, trips *domain.TripService, hubs *handlers.HubManager) {
	group := router.Group("/internal")
	group.Use(middleware.InternalOnly(cfg.InternalAPIKey))

	group.GET("/trips/:id", func(c *gin.Context) {
		tripID := c.Param("id")
		trip, err := trips.Fetch(c.Request.Context(), tripID)
		if err != nil {
			status := http.StatusInternalServerError
			if errors.Is(err, domain.ErrTripNotFound) {
				status = http.StatusNotFound
			}
			c.JSON(status, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, trip)
	})

	group.PATCH("/trips/:id/driver", func(c *gin.Context) {
		tripID := c.Param("id")
		var req struct {
			DriverID *string `json:"driverId"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if req.DriverID != nil {
			trimmed := strings.TrimSpace(*req.DriverID)
			if trimmed == "" {
				req.DriverID = nil
			} else {
				req.DriverID = &trimmed
			}
		}
		if err := trips.AssignDriver(c.Request.Context(), tripID, req.DriverID); err != nil {
			status := http.StatusBadRequest
			if errors.Is(err, domain.ErrTripNotFound) {
				status = http.StatusNotFound
			}
			c.JSON(status, gin.H{"error": err.Error()})
			return
		}
		c.Status(http.StatusNoContent)
	})

	group.POST("/trips/:id/status", func(c *gin.Context) {
		tripID := c.Param("id")
		var req struct {
			Status string `json:"status" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		status := domain.TripStatus(strings.ToLower(strings.TrimSpace(req.Status)))
		if err := trips.UpdateStatus(c.Request.Context(), tripID, status); err != nil {
			statusCode := http.StatusBadRequest
			if errors.Is(err, domain.ErrTripNotFound) {
				statusCode = http.StatusNotFound
			} else if errors.Is(err, domain.ErrInvalidStatus) {
				statusCode = http.StatusBadRequest
			}
			c.JSON(statusCode, gin.H{"error": err.Error()})
			return
		}
		if hubs != nil {
			hubs.BroadcastStatus(tripID, status)
		}
		c.Status(http.StatusNoContent)
	})
}
