package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// TripHandler wires HTTP endpoints for trips.
type TripHandler struct {
	service *domain.TripService
	hubs    *HubManager
}

// RegisterTripRoutes registers trip related routes under /v1.
func RegisterTripRoutes(router *gin.Engine, service *domain.TripService, hubs *HubManager) {
	handler := &TripHandler{
		service: service,
		hubs:    hubs,
	}

	v1 := router.Group("/v1")
	{
		v1.POST("/trips", handler.createTrip)
		v1.GET("/trips/:id", handler.getTrip)
		v1.PATCH("/trips/:id/status", handler.updateTripStatus)
		v1.GET("/trips/:id/ws", hubs.HandleWebsocket(service))
	}
}

type createTripRequest struct {
	OriginText string `json:"originText" binding:"required"`
	DestText   string `json:"destText" binding:"required"`
	ServiceID  string `json:"serviceId" binding:"required"`
}

type updateStatusRequest struct {
	Status string `json:"status" binding:"required"`
}

type tripResponse struct {
	ID           string                 `json:"id"`
	RiderID      string                 `json:"riderId"`
	DriverID     *string                `json:"driverId,omitempty"`
	ServiceID    string                 `json:"serviceId"`
	OriginText   string                 `json:"originText"`
	DestText     string                 `json:"destText"`
	Status       domain.TripStatus      `json:"status"`
	CreatedAt    time.Time              `json:"createdAt"`
	UpdatedAt    time.Time              `json:"updatedAt"`
	LastLocation *domain.LocationUpdate `json:"lastLocation,omitempty"`
}

func toTripResponse(trip *domain.Trip, location *domain.LocationUpdate) tripResponse {
	return tripResponse{
		ID:           trip.ID,
		RiderID:      trip.RiderID,
		DriverID:     trip.DriverID,
		ServiceID:    trip.ServiceID,
		OriginText:   trip.OriginText,
		DestText:     trip.DestText,
		Status:       trip.Status,
		CreatedAt:    trip.CreatedAt,
		UpdatedAt:    trip.UpdatedAt,
		LastLocation: location,
	}
}

func (h *TripHandler) createTrip(c *gin.Context) {
	var req createTripRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID, _ := c.Get("userID")
	riderID, _ := userID.(string)
	if riderID == "" {
		riderID = "demo-user"
	}

	trip := &domain.Trip{
		RiderID:    riderID,
		ServiceID:  req.ServiceID,
		OriginText: req.OriginText,
		DestText:   req.DestText,
	}

	if err := h.service.Create(c.Request.Context(), trip); err != nil {
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
