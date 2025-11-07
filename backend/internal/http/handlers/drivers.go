package handlers

import (
	"net/http"
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
	Latitude   float64 `json:"lat"`
	Longitude  float64 `json:"lng"`
	RecordedAt string  `json:"recordedAt"`
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
	}
	return resp
}
