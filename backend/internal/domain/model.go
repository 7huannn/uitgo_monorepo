package domain

import "time"

// TripStatus represents the lifecycle of a trip.
type TripStatus string

const (
	TripStatusRequested TripStatus = "requested"
	TripStatusAccepted  TripStatus = "accepted"
	TripStatusArriving  TripStatus = "arriving"
	TripStatusInRide    TripStatus = "in_ride"
	TripStatusCompleted TripStatus = "completed"
	TripStatusCancelled TripStatus = "cancelled"
)

// Trip represents a rider trip request.
type Trip struct {
	ID         string     `json:"id"`
	RiderID    string     `json:"riderId"`
	DriverID   *string    `json:"driverId,omitempty"`
	ServiceID  string     `json:"serviceId"`
	OriginText string     `json:"originText"`
	DestText   string     `json:"destText"`
	OriginLat  *float64   `json:"originLat,omitempty"`
	OriginLng  *float64   `json:"originLng,omitempty"`
	DestLat    *float64   `json:"destLat,omitempty"`
	DestLng    *float64   `json:"destLng,omitempty"`
	Status     TripStatus `json:"status"`
	CreatedAt  time.Time  `json:"createdAt"`
	UpdatedAt  time.Time  `json:"updatedAt"`
}

// LocationUpdate represents a driver location ping.
type LocationUpdate struct {
	Latitude  float64   `json:"lat"`
	Longitude float64   `json:"lng"`
	Timestamp time.Time `json:"timestamp"`
}
