package server

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

type DriverTripHandler struct {
	driverService *domain.DriverService
	tripBaseURL   string
	httpClient    *http.Client
}

func NewDriverTripHandler(service *domain.DriverService, tripBaseURL string) *DriverTripHandler {
	return &DriverTripHandler{
		driverService: service,
		tripBaseURL:   strings.TrimSuffix(strings.TrimSpace(tripBaseURL), "/"),
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

func (h *DriverTripHandler) Register(group gin.IRoutes) {
	group.POST("/trips/:id/assign", h.assignDriver)
	group.POST("/trips/:id/accept", h.acceptTrip)
	group.POST("/trips/:id/decline", h.declineTrip)
	group.POST("/trips/:id/status", h.updateStatus)
}

func (h *DriverTripHandler) assignDriver(c *gin.Context) {
	tripID := c.Param("id")
	var req struct {
		DriverID string `json:"driverId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if _, err := h.driverService.AssignTrip(c.Request.Context(), tripID, req.DriverID); err != nil {
		c.JSON(driverErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	h.proxyTripResponse(c, tripID, req.DriverID)
}

func (h *DriverTripHandler) acceptTrip(c *gin.Context) {
	driver, ok := h.requireDriver(c)
	if !ok {
		return
	}
	tripID := c.Param("id")
	if _, err := h.driverService.AcceptTrip(c.Request.Context(), tripID, driver.ID); err != nil {
		c.JSON(driverErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	h.proxyTripResponse(c, tripID, driver.UserID)
}

func (h *DriverTripHandler) declineTrip(c *gin.Context) {
	driver, ok := h.requireDriver(c)
	if !ok {
		return
	}
	tripID := c.Param("id")
	if _, err := h.driverService.DeclineTrip(c.Request.Context(), tripID, driver.ID); err != nil {
		c.JSON(driverErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	h.proxyTripResponse(c, tripID, driver.UserID)
}

func (h *DriverTripHandler) updateStatus(c *gin.Context) {
	driver, ok := h.requireDriver(c)
	if !ok {
		return
	}
	tripID := c.Param("id")
	var req struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	status := domain.TripStatus(strings.ToLower(strings.TrimSpace(req.Status)))
	if _, err := h.driverService.UpdateTripStatus(c.Request.Context(), tripID, driver.ID, status); err != nil {
		c.JSON(driverErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	h.proxyTripResponse(c, tripID, driver.UserID)
}

func (h *DriverTripHandler) requireDriver(c *gin.Context) (*domain.Driver, bool) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return nil, false
	}
	driver, err := h.driverService.Me(c.Request.Context(), userID)
	if err != nil {
		c.JSON(driverErrorStatus(err), gin.H{"error": err.Error()})
		return nil, false
	}
	return driver, true
}

func (h *DriverTripHandler) proxyTripResponse(c *gin.Context, tripID string, userID string) {
	if h.tripBaseURL == "" {
		c.JSON(http.StatusOK, gin.H{"id": tripID})
		return
	}
	url := fmt.Sprintf("%s/v1/trips/%s", h.tripBaseURL, tripID)
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, url, nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	req.Header.Set("X-User-Id", userID)
	req.Header.Set("X-Role", "driver")

	resp, err := h.httpClient.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	for key, values := range resp.Header {
		for _, value := range values {
			c.Writer.Header().Add(key, value)
		}
	}
	c.Status(resp.StatusCode)
	_, _ = io.Copy(c.Writer, resp.Body)
}

func userIDFromContext(c *gin.Context) string {
	val, exists := c.Get("userID")
	if !exists {
		return ""
	}
	if id, ok := val.(string); ok {
		return id
	}
	return ""
}

func driverErrorStatus(err error) int {
	switch err {
	case domain.ErrTripNotFound:
		return http.StatusNotFound
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
