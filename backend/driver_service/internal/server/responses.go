package server

import (
	"time"

	"uitgo/backend/internal/domain"
)

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

func mapDriverResponse(driver *domain.Driver) driverResponse {
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
