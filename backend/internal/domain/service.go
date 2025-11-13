package domain

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// TripService provides business logic for trip workflows.
type TripService struct {
	repo TripRepository
}

// NewTripService creates a TripService.
func NewTripService(repo TripRepository) *TripService {
	return &TripService{repo: repo}
}

// Create registers a new trip for a rider.
func (s *TripService) Create(ctx context.Context, trip *Trip) error {
	if trip.RiderID == "" {
		return errors.New("rider id required")
	}
	if trip.OriginText == "" || trip.DestText == "" {
		return errors.New("origin and destination required")
	}
	if trip.ServiceID == "" {
		return errors.New("service id required")
	}
	if trip.ID == "" {
		trip.ID = uuid.NewString()
	}
	now := time.Now().UTC()
	trip.CreatedAt = now
	trip.UpdatedAt = now
	trip.Status = TripStatusRequested
	return s.repo.CreateTrip(trip)
}

// Fetch retrieves a trip with its current state.
func (s *TripService) Fetch(ctx context.Context, id string) (*Trip, error) {
	return s.repo.GetTrip(id)
}

// UpdateStatus changes the trip status.
func (s *TripService) UpdateStatus(ctx context.Context, id string, status TripStatus) error {
	if !isValidStatus(status) {
		return ErrInvalidStatus
	}
	return s.repo.UpdateTripStatus(id, status)
}

// AssignDriver links/unlinks a driver to the trip.
func (s *TripService) AssignDriver(ctx context.Context, id string, driverID *string) error {
	return s.repo.SetTripDriver(id, driverID)
}

// RecordLocation saves a location update.
func (s *TripService) RecordLocation(ctx context.Context, tripID string, update LocationUpdate) error {
	return s.repo.SaveLocation(tripID, update)
}

// LatestLocation returns the last known driver position.
func (s *TripService) LatestLocation(ctx context.Context, tripID string) (*LocationUpdate, error) {
	return s.repo.GetLatestLocation(tripID)
}

// List returns trips for the current user/role.
func (s *TripService) List(ctx context.Context, userID, role string, limit, offset int) ([]*Trip, int64, error) {
	if userID == "" {
		return nil, 0, errors.New("user id required")
	}
	if role != "driver" {
		role = "rider"
	}
	return s.repo.ListTrips(userID, role, limit, offset)
}

func isValidStatus(status TripStatus) bool {
	switch status {
	case TripStatusRequested,
		TripStatusAccepted,
		TripStatusArriving,
		TripStatusInRide,
		TripStatusCompleted,
		TripStatusCancelled:
		return true
	default:
		return false
	}
}
