package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// DriverHandler exposes driver profile & status endpoints.
type DriverHandler struct {
	service *domain.DriverService
}

// RegisterDriverRoutes wires driver endpoints under /v1.
func RegisterDriverRoutes(router *gin.Engine, service *domain.DriverService) {
	if service == nil {
		return
	}
	handler := &DriverHandler{service: service}
	v1 := router.Group("/v1")
	{
		v1.POST("/drivers", handler.register)
		v1.GET("/drivers/me", handler.me)
		v1.PATCH("/drivers/me", handler.updateProfile)
		v1.PATCH("/drivers/:id/status", handler.updateStatus)
		v1.GET("/drivers/search", handler.searchNearby)
	}
}

type driverVehiclePayload struct {
	Make        string `json:"make" binding:"required"`
	Model       string `json:"model" binding:"required"`
	Color       string `json:"color" binding:"required"`
	Year        int    `json:"year"`
	PlateNumber string `json:"plateNumber" binding:"required"`
}

type createDriverRequest struct {
	FullName      string                `json:"fullName" binding:"required"`
	Phone         string                `json:"phone" binding:"required"`
	LicenseNumber string                `json:"licenseNumber" binding:"required"`
	AvatarURL     *string               `json:"avatarUrl"`
	Vehicle       *driverVehiclePayload `json:"vehicle"`
}

type updateDriverRequest struct {
	FullName      *string               `json:"fullName"`
	Phone         *string               `json:"phone"`
	LicenseNumber *string               `json:"licenseNumber"`
	AvatarURL     *string               `json:"avatarUrl"`
	Vehicle       *driverVehiclePayload `json:"vehicle"`
}

type updateDriverStatusRequest struct {
	Status string `json:"status" binding:"required"`
}

type driverResponse struct {
	ID            string                  `json:"id"`
	UserID        string                  `json:"userId"`
	FullName      string                  `json:"fullName"`
	Phone         string                  `json:"phone"`
	LicenseNumber string                  `json:"licenseNumber"`
	AvatarURL     *string                 `json:"avatarUrl,omitempty"`
	Rating        float64                 `json:"rating"`
	Vehicle       *vehicleResponse        `json:"vehicle,omitempty"`
	Status        *driverStatusResponse   `json:"status,omitempty"`
	Location      *driverLocationResponse `json:"location,omitempty"`
	CreatedAt     string                  `json:"createdAt"`
	UpdatedAt     string                  `json:"updatedAt"`
}

type vehicleResponse struct {
	Make        string `json:"make"`
	Model       string `json:"model"`
	Color       string `json:"color"`
	Year        int    `json:"year"`
	PlateNumber string `json:"plateNumber"`
}

type driverStatusResponse struct {
	Availability domain.DriverAvailability `json:"availability"`
	UpdatedAt    string                    `json:"updatedAt"`
}

type driverLocationResponse struct {
	Latitude       float64  `json:"lat"`
	Longitude      float64  `json:"lng"`
	RecordedAt     string   `json:"recordedAt"`
	DistanceMeters *float64 `json:"distanceMeters,omitempty"`
}

func (h *DriverHandler) register(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	var req createDriverRequest
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
		input.Vehicle = payloadToVehicle(req.Vehicle)
	}

	driver, err := h.service.Register(c.Request.Context(), userID, input)
	if err != nil {
		status := http.StatusInternalServerError
		switch err {
		case domain.ErrDriverAlreadyExists:
			status = http.StatusConflict
		default:
			if strings.Contains(err.Error(), "full name required") {
				status = http.StatusBadRequest
			}
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, toDriverResponse(driver))
}

func (h *DriverHandler) me(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}
	driver, err := h.service.Me(c.Request.Context(), userID)
	if err != nil {
		status := http.StatusInternalServerError
		if err == domain.ErrDriverNotFound {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toDriverResponse(driver))
}

func (h *DriverHandler) updateProfile(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}
	var req updateDriverRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	update := domain.DriverProfileUpdate{
		FullName:      req.FullName,
		Phone:         req.Phone,
		LicenseNumber: req.LicenseNumber,
		AvatarURL:     req.AvatarURL,
	}
	if req.Vehicle != nil {
		update.Vehicle = payloadToVehicle(req.Vehicle)
	}
	driver, err := h.service.UpdateProfile(c.Request.Context(), userID, update)
	if err != nil {
		status := http.StatusInternalServerError
		if err == domain.ErrDriverNotFound {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toDriverResponse(driver))
}

func (h *DriverHandler) updateStatus(c *gin.Context) {
	driverID := c.Param("id")
	if driverID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "driver id required"})
		return
	}
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}
	driver, err := h.service.Me(c.Request.Context(), userID)
	if err != nil {
		status := http.StatusInternalServerError
		if err == domain.ErrDriverNotFound {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	if driver.ID != driverID {
		c.JSON(http.StatusForbidden, gin.H{"error": "cannot update other driver"})
		return
	}

	var req updateDriverStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	statusValue := strings.ToLower(strings.TrimSpace(req.Status))
	var availability domain.DriverAvailability
	switch statusValue {
	case "online":
		availability = domain.DriverOnline
	case "offline":
		availability = domain.DriverOffline
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "status must be online or offline"})
		return
	}
	status, err := h.service.UpdateAvailability(c.Request.Context(), driverID, availability)
	if err != nil {
		statusCode := http.StatusInternalServerError
		if err == domain.ErrDriverNotFound {
			statusCode = http.StatusNotFound
		}
		c.JSON(statusCode, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, driverStatusResponse{
		Availability: status.Availability,
		UpdatedAt:    status.UpdatedAt.UTC().Format(time.RFC3339),
	})
}

func (h *DriverHandler) searchNearby(c *gin.Context) {
	if h.service == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "driver service unavailable"})
		return
	}
	latStr := strings.TrimSpace(c.Query("lat"))
	lngStr := strings.TrimSpace(c.Query("lng"))
	if latStr == "" || lngStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "lat and lng are required"})
		return
	}
	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid lat"})
		return
	}
	lng, err := strconv.ParseFloat(lngStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid lng"})
		return
	}
	radiusMeters := parseFloatDefault(c.DefaultQuery("radius", "3000"), 3000)
	limit := parseIntDefault(c.DefaultQuery("limit", "10"), 10, 50)
	drivers, err := h.service.SearchNearbyDrivers(c.Request.Context(), lat, lng, radiusMeters, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	items := make([]driverResponse, 0, len(drivers))
	for _, driver := range drivers {
		items = append(items, toDriverResponse(driver))
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}

func payloadToVehicle(payload *driverVehiclePayload) *domain.Vehicle {
	if payload == nil {
		return nil
	}
	return &domain.Vehicle{
		Make:        payload.Make,
		Model:       payload.Model,
		Color:       payload.Color,
		Year:        payload.Year,
		PlateNumber: payload.PlateNumber,
	}
}

func toDriverResponse(driver *domain.Driver) driverResponse {
	resp := driverResponse{
		ID:            driver.ID,
		UserID:        driver.UserID,
		FullName:      driver.FullName,
		Phone:         driver.Phone,
		LicenseNumber: driver.LicenseNumber,
		AvatarURL:     driver.AvatarURL,
		Rating:        driver.Rating,
		CreatedAt:     driver.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:     driver.UpdatedAt.UTC().Format(time.RFC3339),
	}
	if driver.Vehicle != nil {
		resp.Vehicle = &vehicleResponse{
			Make:        driver.Vehicle.Make,
			Model:       driver.Vehicle.Model,
			Color:       driver.Vehicle.Color,
			Year:        driver.Vehicle.Year,
			PlateNumber: driver.Vehicle.PlateNumber,
		}
	}
	if driver.Status != nil {
		resp.Status = &driverStatusResponse{
			Availability: driver.Status.Availability,
			UpdatedAt:    driver.Status.UpdatedAt.UTC().Format(time.RFC3339),
		}
	}
	if driver.Location != nil {
		resp.Location = &driverLocationResponse{
			Latitude:   driver.Location.Latitude,
			Longitude:  driver.Location.Longitude,
			RecordedAt: driver.Location.RecordedAt.UTC().Format(time.RFC3339),
		}
		if driver.Location.DistanceMeters != nil {
			resp.Location.DistanceMeters = driver.Location.DistanceMeters
		}
	}
	return resp
}

func parseFloatDefault(value string, defaultValue float64) float64 {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return defaultValue
	}
	f, err := strconv.ParseFloat(trimmed, 64)
	if err != nil || f <= 0 {
		return defaultValue
	}
	return f
}

func parseIntDefault(value string, defaultValue, max int) int {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(trimmed)
	if err != nil || parsed <= 0 {
		return defaultValue
	}
	if parsed > max && max > 0 {
		return max
	}
	return parsed
}
