package server

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
)

// Server hosts the driver-service HTTP API.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// New builds the server with driver/profile routes and internal hooks.
func New(cfg *config.Config, db *gorm.DB, tripSync domain.TripSyncRepository) (*Server, error) {
	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.Auth(cfg.JWTSecret))

	handlers.RegisterHealth(router)

	driverRepo := dbrepo.NewDriverRepository(db)
	assignmentRepo := dbrepo.NewTripAssignmentRepository(db)
	driverService := domain.NewDriverService(driverRepo, assignmentRepo, tripSync)

	handlers.RegisterDriverRoutes(router, driverService)

	tripHandler := NewDriverTripHandler(driverService, cfg.TripServiceURL)
	tripHandler.Register(router.Group("/v1"))

	registerInternalRoutes(router, cfg, driverRepo, driverService)

	return &Server{engine: router, cfg: cfg}, nil
}

// Run starts the HTTP listener.
func (s *Server) Run() error {
	addr := fmt.Sprintf(":%s", s.cfg.Port)
	return s.engine.Run(addr)
}

func registerInternalRoutes(router gin.IRouter, cfg *config.Config, drivers domain.DriverRepository, service *domain.DriverService) {
	group := router.Group("/internal")
	group.Use(middleware.InternalOnly(cfg.InternalAPIKey))

	group.POST("/drivers", func(c *gin.Context) {
		var req struct {
			UserID        string  `json:"userId" binding:"required"`
			FullName      string  `json:"fullName" binding:"required"`
			Phone         string  `json:"phone" binding:"required"`
			LicenseNumber string  `json:"licenseNumber" binding:"required"`
			AvatarURL     *string `json:"avatarUrl"`
			Vehicle       *struct {
				Make        string `json:"make"`
				Model       string `json:"model"`
				Color       string `json:"color"`
				Year        int    `json:"year"`
				PlateNumber string `json:"plateNumber"`
			} `json:"vehicle"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		input := domain.DriverRegistrationInput{
			FullName:      req.FullName,
			Phone:         req.Phone,
			LicenseNumber: req.LicenseNumber,
			AvatarURL:     req.AvatarURL,
		}
		if req.Vehicle != nil {
			input.Vehicle = &domain.Vehicle{
				Make:        req.Vehicle.Make,
				Model:       req.Vehicle.Model,
				Color:       req.Vehicle.Color,
				Year:        req.Vehicle.Year,
				PlateNumber: req.Vehicle.PlateNumber,
			}
		}
		driver, err := service.Register(c.Request.Context(), req.UserID, input)
		if err != nil {
			status := http.StatusInternalServerError
			if err == domain.ErrDriverAlreadyExists {
				status = http.StatusConflict
			}
			c.JSON(status, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusCreated, mapDriverResponse(driver))
	})

	group.POST("/driver-locations", func(c *gin.Context) {
		var req struct {
			DriverID   string    `json:"driverId" binding:"required"`
			Lat        float64   `json:"lat" binding:"required"`
			Lng        float64   `json:"lng" binding:"required"`
			Accuracy   *float64  `json:"accuracy"`
			Heading    *float64  `json:"heading"`
			Speed      *float64  `json:"speed"`
			RecordedAt time.Time `json:"recordedAt"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		timestamp := req.RecordedAt
		if timestamp.IsZero() {
			timestamp = time.Now().UTC()
		}
		location := &domain.DriverLocation{
			DriverID:   req.DriverID,
			Latitude:   req.Lat,
			Longitude:  req.Lng,
			Accuracy:   req.Accuracy,
			Heading:    req.Heading,
			Speed:      req.Speed,
			RecordedAt: timestamp,
		}
		if err := drivers.RecordLocation(c.Request.Context(), req.DriverID, location); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.Status(http.StatusAccepted)
	})
}
