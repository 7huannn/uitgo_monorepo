package server

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
	"uitgo/backend/internal/location"
	"uitgo/backend/internal/matching"
	"uitgo/backend/internal/notification"
	"uitgo/backend/internal/observability"
)

const driverServiceName = "driver-service"

// Server hosts the driver-service HTTP API.
type Server struct {
	engine      *gin.Engine
	cfg         *config.Config
	queue       matching.Queue
	queueCancel context.CancelFunc
}

// setupRouter creates and configures the gin router with middleware.
func setupRouter(cfg *config.Config, db *gorm.DB) *gin.Engine {
	router := gin.New()
	gin.DisableConsoleColor()
	router.Use(otelgin.Middleware(driverServiceName))
	router.Use(middleware.JSONLogger(driverServiceName))
	router.Use(observability.GinMiddleware())
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.Auth(cfg.JWTSecret, cfg.InternalAPIKey))

	metrics := middleware.NewHTTPMetrics(driverServiceName, cfg.PrometheusEnabled)
	router.Use(metrics.Handler())

	auditRepo := domain.NewAuditLogRepository(db)
	router.Use(middleware.AuditLogger(auditRepo))

	handlers.RegisterHealth(router)
	metrics.Expose(router)

	return router
}

// createDriverService initializes the driver service with all dependencies.
func createDriverService(cfg *config.Config, db *gorm.DB) (*domain.DriverService, error) {
	driverRepo := dbrepo.NewDriverRepository(db)
	assignmentRepo := dbrepo.NewTripAssignmentRepository(db)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	deviceTokenRepo := dbrepo.NewDeviceTokenRepository(db)

	pushSender, err := notification.BuildSenderFromConfig(context.Background(), cfg)
	if err != nil {
		log.Printf("warn: unable to initialize FCM: %v", err)
	}
	notificationSvc := notification.NewService(notificationRepo, deviceTokenRepo, pushSender)

	locator, err := location.NewGeoIndex(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB, "driver")
	if err != nil {
		return nil, fmt.Errorf("init redis geo index: %w", err)
	}

	return domain.NewDriverService(driverRepo, assignmentRepo, nil, notificationSvc, locator), nil
}

// createMatchQueue initializes the matching queue.
func createMatchQueue(cfg *config.Config) matching.Queue {
	queue, err := matching.NewQueue(context.Background(), matching.QueueOptions{
		Backend:       cfg.MatchQueueBackend,
		RedisAddr:     cfg.MatchQueueAddr,
		RedisPassword: cfg.RedisPassword,
		RedisDB:       cfg.MatchQueueDB,
		QueueName:     cfg.MatchQueueName,
		SQSQueueURL:   cfg.MatchQueueSQSURL,
		SQSRegion:     cfg.AWSRegion,
	})
	if err != nil {
		log.Printf("warn: init trip queue failed: %v", err)
		return nil
	}
	return queue
}

// New builds the server with driver/profile routes and internal hooks.
func New(cfg *config.Config, db *gorm.DB, tripSync domain.TripSyncRepository) (*Server, error) {
	router := setupRouter(cfg, db)

	driverService, err := createDriverService(cfg, db)
	if err != nil {
		return nil, err
	}

	handlers.RegisterDriverRoutes(router, driverService)

	tripHandler := NewDriverTripHandler(driverService, cfg.TripServiceURL, cfg.InternalAPIKey)
	tripHandler.Register(router.Group("/v1"))

	registerInternalRoutes(router, cfg, driverService)

	matchQueue := createMatchQueue(cfg)
	var cancel context.CancelFunc
	if matchQueue != nil {
		ctx, c := context.WithCancel(context.Background())
		cancel = c
		go consumeTripQueue(ctx, matchQueue, driverService)
	}

	return &Server{engine: router, cfg: cfg, queue: matchQueue, queueCancel: cancel}, nil
}

// Run starts the HTTP listener.
func (s *Server) Run() error {
	addr := fmt.Sprintf(":%s", s.cfg.Port)
	defer func() {
		if s.queueCancel != nil {
			s.queueCancel()
		}
		if s.queue != nil {
			_ = s.queue.Close()
		}
	}()
	return s.engine.Run(addr)
}

func registerInternalRoutes(router gin.IRouter, cfg *config.Config, service *domain.DriverService) {
	group := router.Group("/internal")
	group.Use(middleware.InternalOnly(cfg.InternalAPIKey))

	group.POST("/drivers", createDriverHandler(service))
	group.POST("/driver-locations", recordLocationHandler(service))
	group.DELETE("/trip-assignments", clearAssignmentsHandler(service))
}

type createDriverRequest struct {
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

func createDriverHandler(service *domain.DriverService) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req createDriverRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		input := buildDriverRegistrationInput(req)
		driver, err := service.Register(c.Request.Context(), req.UserID, input)
		if err != nil {
			handleDriverRegistrationError(c, err)
			return
		}
		c.JSON(http.StatusCreated, mapDriverResponse(driver))
	}
}

func buildDriverRegistrationInput(req createDriverRequest) domain.DriverRegistrationInput {
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
	return input
}

func handleDriverRegistrationError(c *gin.Context, err error) {
	status := http.StatusInternalServerError
	if err == domain.ErrDriverAlreadyExists || err == domain.ErrVehicleAlreadyExists {
		status = http.StatusConflict
	}
	c.JSON(status, gin.H{"error": err.Error()})
}

type recordLocationRequest struct {
	DriverID   string    `json:"driverId" binding:"required"`
	Lat        float64   `json:"lat" binding:"required"`
	Lng        float64   `json:"lng" binding:"required"`
	Accuracy   *float64  `json:"accuracy"`
	Heading    *float64  `json:"heading"`
	Speed      *float64  `json:"speed"`
	RecordedAt time.Time `json:"recordedAt"`
}

func recordLocationHandler(service *domain.DriverService) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req recordLocationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		location := buildDriverLocation(req)
		if err := service.RecordLocation(c.Request.Context(), req.DriverID, location); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.Status(http.StatusAccepted)
	}
}

func buildDriverLocation(req recordLocationRequest) *domain.DriverLocation {
	timestamp := req.RecordedAt
	if timestamp.IsZero() {
		timestamp = time.Now().UTC()
	}
	return &domain.DriverLocation{
		DriverID:   req.DriverID,
		Latitude:   req.Lat,
		Longitude:  req.Lng,
		Accuracy:   req.Accuracy,
		Heading:    req.Heading,
		Speed:      req.Speed,
		RecordedAt: timestamp,
	}
}

func clearAssignmentsHandler(service *domain.DriverService) gin.HandlerFunc {
	return func(c *gin.Context) {
		if err := service.ClearAssignments(c.Request.Context()); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.Status(http.StatusNoContent)
	}
}

func consumeTripQueue(ctx context.Context, queue matching.TripConsumer, driverService *domain.DriverService) {
	if queue == nil || driverService == nil {
		return
	}
	log.Println("trip queue consumer started")
	if err := queue.Consume(ctx, func(ctx context.Context, event *matching.TripEvent) error {
		if event == nil || event.TripID == "" {
			return nil
		}
		_, err := driverService.AssignNextAvailableDriver(ctx, event.TripID)
		if err != nil && !errors.Is(err, domain.ErrNoDriversAvailable) {
			return err
		}
		return nil
	}); err != nil && !errors.Is(err, context.Canceled) {
		log.Printf("trip queue consumer stopped: %v", err)
	} else {
		log.Println("trip queue consumer stopped")
	}
}
