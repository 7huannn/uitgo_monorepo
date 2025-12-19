package domain

// TripRepository defines persistence operations for trips and events.
type TripRepository interface {
	CreateTrip(trip *Trip) error
	GetTrip(id string) (*Trip, error)
	UpdateTripStatus(id string, status TripStatus) error
	SetTripDriver(id string, driverID *string) error
	SaveLocation(tripID string, update LocationUpdate) error
	GetLatestLocation(tripID string) (*LocationUpdate, error)
	ListTrips(userID string, role string, limit, offset int) ([]*Trip, int64, error)
	PurgeAll() error
}

// TripSyncRepository exposes the subset of trip operations needed by the driver service.
type TripSyncRepository interface {
	GetTrip(id string) (*Trip, error)
	UpdateTripStatus(id string, status TripStatus) error
	SetTripDriver(id string, driverID *string) error
}
