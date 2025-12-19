package server

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	dbrepo "uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/http/middleware"
	"uitgo/backend/internal/matching"
	"uitgo/backend/internal/notification"
	"uitgo/backend/internal/observability"
	"uitgo/backend/internal/routing"
)

// Server represents the trip-service HTTP server.
type Server struct {
	engine *gin.Engine
	cfg    *config.Config
}

// New constructs the HTTP server with trip routes and internal hooks.
func New(cfg *config.Config, db *gorm.DB, readDB *gorm.DB, driverLocations handlers.DriverLocationWriter, dispatcher matching.TripDispatcher, wallets domain.WalletOperations) (*Server, error) {
	const serviceName = "trip-service"
	router := gin.New()
	gin.DisableConsoleColor()
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
	routeProvider := routing.NewClient(cfg.RoutingBaseURL, 8*time.Second, 5*time.Minute)
	handlers.RegisterRouteRoutes(router, routeProvider)
	// Increased from 10 to 1000 for load testing
	tripLimiter := middleware.NewTokenBucketRateLimiter(1000, time.Minute)

	tripRepo := dbrepo.NewTripRepositoryWithReplica(db, readDB)
	notificationRepo := dbrepo.NewNotificationRepository(db)
	deviceTokenRepo := dbrepo.NewDeviceTokenRepository(db)
	pushSender, err := notification.BuildSenderFromConfig(context.Background(), cfg)
	if err != nil {
		log.Printf("warn: unable to initialize FCM: %v", err)
	}
	notificationSvc := notification.NewService(notificationRepo, deviceTokenRepo, pushSender)
	tripService := domain.NewTripService(tripRepo, wallets, notificationSvc)
	hubManager := handlers.NewHubManager(tripService, driverLocations)

	handlers.RegisterTripRoutes(router, tripService, nil, hubManager, dispatcher, tripLimiter.Middleware("trip_create"))
	registerInternalRoutes(router, cfg, tripService, hubManager)

	metrics.Expose(router)

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

	group.DELETE("/trips", func(c *gin.Context) {
		if err := trips.PurgeAll(c.Request.Context()); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
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
			} else if errors.Is(err, domain.ErrWalletInsufficientFunds) {
				statusCode = http.StatusPaymentRequired
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
