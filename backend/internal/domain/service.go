package domain

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/google/uuid"
)

// TripService provides business logic for trip workflows.
type TripService struct {
	repo     TripRepository
	wallets  WalletOperations
	notifier TripEventNotifier
}

// NewTripService creates a TripService.
func NewTripService(repo TripRepository, wallets WalletOperations, notifier TripEventNotifier) *TripService {
	return &TripService{
		repo:     repo,
		wallets:  wallets,
		notifier: notifier,
	}
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
	if s.wallets != nil {
		if _, err := s.wallets.EnsureBalanceForTrip(ctx, trip.RiderID, trip.ServiceID); err != nil {
			return err
		}
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
	var trip *Trip
	var err error
	needsWallet := s.wallets != nil && status == TripStatusCompleted
	needsTripForNotification := s.notifier != nil && (status == TripStatusArriving || status == TripStatusCompleted)
	if needsWallet || needsTripForNotification {
		trip, err = s.repo.GetTrip(id)
		if err != nil {
			return err
		}
	}

	if err := s.repo.UpdateTripStatus(id, status); err != nil {
		return err
	}

	if needsWallet && trip != nil && trip.Status != TripStatusCompleted {
		if _, _, err := s.wallets.DeductTripFare(ctx, trip.RiderID, trip.ServiceID); err != nil {
			return err
		}
		if _, _, err := s.wallets.RewardTripCompletion(ctx, trip.RiderID); err != nil {
			return err
		}
	}
	if trip != nil {
		trip.Status = status
	}
	if s.notifier != nil && trip != nil {
		if err := s.notifier.NotifyRiderStatusChange(ctx, trip, status); err != nil {
			log.Printf("notify rider status: %v", err)
		}
	}
	return nil
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

// PurgeAll removes all trips and related events (dev/demo cleanup).
func (s *TripService) PurgeAll(_ context.Context) error {
	if s.repo == nil {
		return errors.New("trip repo not configured")
	}
	return s.repo.PurgeAll()
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
