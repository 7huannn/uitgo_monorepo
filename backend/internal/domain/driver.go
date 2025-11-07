package domain

import (
	"context"
	"time"
)

// DriverAvailability indicates whether a driver is accepting trips.
type DriverAvailability string

const (
	DriverOffline DriverAvailability = "offline"
	DriverOnline  DriverAvailability = "online"
)

// Driver captures driver profile & vehicle snapshot.
type Driver struct {
	ID            string          `json:"id"`
	UserID        string          `json:"userId"`
	FullName      string          `json:"fullName"`
	Phone         string          `json:"phone"`
	LicenseNumber string          `json:"licenseNumber"`
	AvatarURL     *string         `json:"avatarUrl,omitempty"`
	Rating        float64         `json:"rating"`
	CreatedAt     time.Time       `json:"createdAt"`
	UpdatedAt     time.Time       `json:"updatedAt"`
	Vehicle       *Vehicle        `json:"vehicle,omitempty"`
	Status        *DriverStatus   `json:"status,omitempty"`
	Location      *DriverLocation `json:"location,omitempty"`
}

// Vehicle stores driver vehicle information.
type Vehicle struct {
	ID          string    `json:"id"`
	DriverID    string    `json:"driverId"`
	Make        string    `json:"make"`
	Model       string    `json:"model"`
	Color       string    `json:"color"`
	Year        int       `json:"year"`
	PlateNumber string    `json:"plateNumber"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// DriverStatus records online/offline state.
type DriverStatus struct {
	DriverID     string             `json:"driverId"`
	Availability DriverAvailability `json:"availability"`
	UpdatedAt    time.Time          `json:"updatedAt"`
}

// DriverLocation stores a location ping for the driver.
type DriverLocation struct {
	ID         string    `json:"id"`
	DriverID   string    `json:"driverId"`
	Latitude   float64   `json:"lat"`
	Longitude  float64   `json:"lng"`
	Accuracy   *float64  `json:"accuracy,omitempty"`
	Heading    *float64  `json:"heading,omitempty"`
	Speed      *float64  `json:"speed,omitempty"`
	RecordedAt time.Time `json:"recordedAt"`
}

// TripAssignmentStatus enumerates assignment lifecycle states.
type TripAssignmentStatus string

const (
	TripAssignmentPending   TripAssignmentStatus = "pending"
	TripAssignmentAccepted  TripAssignmentStatus = "accepted"
	TripAssignmentDeclined  TripAssignmentStatus = "declined"
	TripAssignmentCancelled TripAssignmentStatus = "cancelled"
)

// TripAssignment links a driver to a trip.
type TripAssignment struct {
	ID          string               `json:"id"`
	TripID      string               `json:"tripId"`
	DriverID    string               `json:"driverId"`
	Status      TripAssignmentStatus `json:"status"`
	RespondedAt *time.Time           `json:"respondedAt,omitempty"`
	CreatedAt   time.Time            `json:"createdAt"`
	UpdatedAt   time.Time            `json:"updatedAt"`
}

// DriverRepository exposes persistence for driver entities.
type DriverRepository interface {
	Create(ctx context.Context, driver *Driver) error
	Update(ctx context.Context, driver *Driver) error
	FindByID(ctx context.Context, id string) (*Driver, error)
	FindByUserID(ctx context.Context, userID string) (*Driver, error)
	SaveVehicle(ctx context.Context, vehicle *Vehicle) (*Vehicle, error)
	FindVehicle(ctx context.Context, driverID string) (*Vehicle, error)
	SetAvailability(ctx context.Context, driverID string, availability DriverAvailability) (*DriverStatus, error)
	GetAvailability(ctx context.Context, driverID string) (*DriverStatus, error)
	RecordLocation(ctx context.Context, driverID string, location *DriverLocation) error
	LatestLocation(ctx context.Context, driverID string) (*DriverLocation, error)
}

// TripAssignmentRepository handles driver-trip links.
type TripAssignmentRepository interface {
	Assign(ctx context.Context, tripID, driverID string) (*TripAssignment, error)
	UpdateStatus(ctx context.Context, tripID, driverID string, status TripAssignmentStatus, respondedAt *time.Time) (*TripAssignment, error)
	GetByTripID(ctx context.Context, tripID string) (*TripAssignment, error)
	FindActiveByDriver(ctx context.Context, driverID string) (*TripAssignment, error)
	Clear(ctx context.Context, tripID string) error
}
