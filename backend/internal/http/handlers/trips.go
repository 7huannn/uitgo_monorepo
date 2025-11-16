package handlers

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// TripHandler wires HTTP endpoints for trips.
type TripHandler struct {
	service       *domain.TripService
	driverService *domain.DriverService
	hubs          *HubManager
}

// RegisterTripRoutes registers trip related routes under /v1.
func RegisterTripRoutes(router gin.IRouter, service *domain.TripService, driverService *domain.DriverService, hubs *HubManager, createTripMiddlewares ...gin.HandlerFunc) {
	handler := &TripHandler{
		service:       service,
		driverService: driverService,
		hubs:          hubs,
	}

	v1 := router.Group("/v1")
	{
		v1.GET("/trips", handler.listTrips)
		createTripHandlers := append([]gin.HandlerFunc{}, createTripMiddlewares...)
		createTripHandlers = append(createTripHandlers, handler.createTrip)
		v1.POST("/trips", createTripHandlers...)
		v1.GET("/trips/:id", handler.getTrip)
		v1.PATCH("/trips/:id/status", handler.updateTripStatus)
		v1.POST("/trips/:id/assign", handler.assignDriver)
		v1.POST("/trips/:id/accept", handler.acceptTrip)
		v1.POST("/trips/:id/decline", handler.declineTrip)
		v1.POST("/trips/:id/status", handler.driverUpdateTripStatus)
		v1.GET("/trips/:id/ws", hubs.HandleWebsocket(service))
	}
}

type createTripRequest struct {
	OriginText string   `json:"originText" binding:"required"`
	DestText   string   `json:"destText" binding:"required"`
	ServiceID  string   `json:"serviceId" binding:"required"`
	OriginLat  *float64 `json:"originLat"`
	OriginLng  *float64 `json:"originLng"`
	DestLat    *float64 `json:"destLat"`
	DestLng    *float64 `json:"destLng"`
}

type updateStatusRequest struct {
	Status string `json:"status" binding:"required"`
}

type assignTripRequest struct {
	DriverID string `json:"driverId" binding:"required"`
}

type tripResponse struct {
	ID           string                 `json:"id"`
	RiderID      string                 `json:"riderId"`
	DriverID     *string                `json:"driverId,omitempty"`
	ServiceID    string                 `json:"serviceId"`
	OriginText   string                 `json:"originText"`
	DestText     string                 `json:"destText"`
	OriginLat    *float64               `json:"originLat,omitempty"`
	OriginLng    *float64               `json:"originLng,omitempty"`
	DestLat      *float64               `json:"destLat,omitempty"`
	DestLng      *float64               `json:"destLng,omitempty"`
	Status       domain.TripStatus      `json:"status"`
	CreatedAt    time.Time              `json:"createdAt"`
	UpdatedAt    time.Time              `json:"updatedAt"`
	LastLocation *domain.LocationUpdate `json:"lastLocation,omitempty"`
}

type tripListResponse struct {
	Items  []tripResponse `json:"items"`
	Total  int64          `json:"total"`
	Limit  int            `json:"limit"`
	Offset int            `json:"offset"`
}

func toTripResponse(trip *domain.Trip, location *domain.LocationUpdate) tripResponse {
	return tripResponse{
		ID:           trip.ID,
		RiderID:      trip.RiderID,
		DriverID:     trip.DriverID,
		ServiceID:    trip.ServiceID,
		OriginText:   trip.OriginText,
		DestText:     trip.DestText,
		OriginLat:    trip.OriginLat,
		OriginLng:    trip.OriginLng,
		DestLat:      trip.DestLat,
		DestLng:      trip.DestLng,
		Status:       trip.Status,
		CreatedAt:    trip.CreatedAt,
		UpdatedAt:    trip.UpdatedAt,
		LastLocation: location,
	}
}

func (h *TripHandler) listTrips(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	role := strings.ToLower(c.DefaultQuery("role", "rider"))
	if role != "driver" {
		role = "rider"
	}

	limit := queryInt(c, "limit", 20, 100)
	offset := queryInt(c, "offset", 0, 1000)
	page := queryInt(c, "page", 0, 10000)
	pageSize := queryInt(c, "pageSize", 0, 100)
	if page > 0 {
		if pageSize <= 0 {
			pageSize = limit
		}
		if pageSize > 100 {
			pageSize = 100
		}
		limit = pageSize
		offset = (page - 1) * pageSize
	}

	trips, total, err := h.service.List(c.Request.Context(), userID, role, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list trips"})
		return
	}

	resp := tripListResponse{
		Items:  make([]tripResponse, 0, len(trips)),
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}
	for _, trip := range trips {
		resp.Items = append(resp.Items, toTripResponse(trip, nil))
	}
	c.JSON(http.StatusOK, resp)
}

func (h *TripHandler) createTrip(c *gin.Context) {
	var req createTripRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	riderID := userIDFromContext(c)
	if riderID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	trip := &domain.Trip{
		RiderID:    riderID,
		ServiceID:  req.ServiceID,
		OriginText: req.OriginText,
		DestText:   req.DestText,
		OriginLat:  req.OriginLat,
		OriginLng:  req.OriginLng,
		DestLat:    req.DestLat,
		DestLng:    req.DestLng,
	}

	if err := h.service.Create(c.Request.Context(), trip); err != nil {
		if errors.Is(err, domain.ErrWalletInsufficientFunds) {
			c.JSON(http.StatusPaymentRequired, gin.H{"error": "insufficient wallet balance"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, toTripResponse(trip, nil))
}

func (h *TripHandler) getTrip(c *gin.Context) {
	tripID := c.Param("id")
	trip, err := h.service.Fetch(c.Request.Context(), tripID)
	if err != nil {
		if errors.Is(err, domain.ErrTripNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "trip not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	location, err := h.service.LatestLocation(c.Request.Context(), tripID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, toTripResponse(trip, location))
}

func (h *TripHandler) updateTripStatus(c *gin.Context) {
	tripID := c.Param("id")
	var req updateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	status := domain.TripStatus(req.Status)
	if status == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "status required"})
		return
	}

	if err := h.service.UpdateStatus(c.Request.Context(), tripID, status); err != nil {
		if errors.Is(err, domain.ErrTripNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "trip not found"})
			return
		}
		if errors.Is(err, domain.ErrInvalidStatus) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid status"})
			return
		}
		if errors.Is(err, domain.ErrWalletInsufficientFunds) {
			c.JSON(http.StatusPaymentRequired, gin.H{"error": "insufficient wallet balance"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	h.hubs.BroadcastStatus(tripID, status)

	trip, err := h.service.Fetch(c.Request.Context(), tripID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"id":        tripID,
			"status":    status,
			"updatedAt": time.Now().UTC(),
		})
		return
	}
	location, _ := h.service.LatestLocation(c.Request.Context(), tripID)

	c.JSON(http.StatusOK, toTripResponse(trip, location))
}

func (h *TripHandler) assignDriver(c *gin.Context) {
	if h.driverService == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "driver dispatch unavailable"})
		return
	}
	tripID := c.Param("id")
	if tripID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "trip id required"})
		return
	}
	var req assignTripRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if _, err := h.driverService.AssignTrip(c.Request.Context(), tripID, req.DriverID); err != nil {
		status := driverErrorStatus(err)
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	trip, err := h.service.Fetch(c.Request.Context(), tripID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch trip"})
		return
	}
	location, _ := h.service.LatestLocation(c.Request.Context(), tripID)
	c.JSON(http.StatusOK, toTripResponse(trip, location))
}

func (h *TripHandler) acceptTrip(c *gin.Context) {
	driver, ok := h.requireDriver(c)
	if !ok {
		return
	}
	tripID := c.Param("id")
	if tripID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "trip id required"})
		return
	}
	if _, err := h.driverService.AcceptTrip(c.Request.Context(), tripID, driver.ID); err != nil {
		status := driverErrorStatus(err)
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	h.hubs.BroadcastStatus(tripID, domain.TripStatusAccepted)
	trip, err := h.service.Fetch(c.Request.Context(), tripID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch trip"})
		return
	}
	location, _ := h.service.LatestLocation(c.Request.Context(), tripID)
	c.JSON(http.StatusOK, toTripResponse(trip, location))
}

func (h *TripHandler) declineTrip(c *gin.Context) {
	driver, ok := h.requireDriver(c)
	if !ok {
		return
	}
	tripID := c.Param("id")
	if tripID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "trip id required"})
		return
	}
	if _, err := h.driverService.DeclineTrip(c.Request.Context(), tripID, driver.ID); err != nil {
		status := driverErrorStatus(err)
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	trip, err := h.service.Fetch(c.Request.Context(), tripID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch trip"})
		return
	}
	location, _ := h.service.LatestLocation(c.Request.Context(), tripID)
	c.JSON(http.StatusOK, toTripResponse(trip, location))
}

func (h *TripHandler) driverUpdateTripStatus(c *gin.Context) {
	driver, ok := h.requireDriver(c)
	if !ok {
		return
	}
	tripID := c.Param("id")
	if tripID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "trip id required"})
		return
	}
	var req updateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	status := domain.TripStatus(strings.ToLower(strings.TrimSpace(req.Status)))
	trip, err := h.driverService.UpdateTripStatus(c.Request.Context(), tripID, driver.ID, status)
	if err != nil {
		statusCode := driverErrorStatus(err)
		c.JSON(statusCode, gin.H{"error": err.Error()})
		return
	}
	h.hubs.BroadcastStatus(tripID, status)
	location, _ := h.service.LatestLocation(c.Request.Context(), tripID)
	c.JSON(http.StatusOK, toTripResponse(trip, location))
}

func (h *TripHandler) requireDriver(c *gin.Context) (*domain.Driver, bool) {
	if h.driverService == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "driver dispatch unavailable"})
		return nil, false
	}
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return nil, false
	}
	driver, err := h.driverService.Me(c.Request.Context(), userID)
	if err != nil {
		status := driverErrorStatus(err)
		c.JSON(status, gin.H{"error": err.Error()})
		return nil, false
	}
	return driver, true
}

func driverErrorStatus(err error) int {
	switch err {
	case domain.ErrTripNotFound:
		return http.StatusNotFound
	case domain.ErrWalletInsufficientFunds:
		return http.StatusPaymentRequired
	case domain.ErrDriverNotFound, domain.ErrTripAssignmentNotFound:
		return http.StatusNotFound
	case domain.ErrDriverOffline, domain.ErrAssignmentConflict:
		return http.StatusConflict
	case domain.ErrInvalidStatus:
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}
