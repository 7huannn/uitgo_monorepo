package domain_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"uitgo/backend/internal/domain"
)

type stubRepo struct {
	trips        map[string]*domain.Trip
	statuses     map[string]domain.TripStatus
	lastLocation *domain.LocationUpdate
}

var _ domain.TripRepository = (*stubRepo)(nil)

func newStubRepo() *stubRepo {
	return &stubRepo{
		trips:    make(map[string]*domain.Trip),
		statuses: make(map[string]domain.TripStatus),
	}
}

func (s *stubRepo) CreateTrip(trip *domain.Trip) error {
	s.trips[trip.ID] = trip
	s.statuses[trip.ID] = trip.Status
	return nil
}

func (s *stubRepo) GetTrip(id string) (*domain.Trip, error) {
	trip, ok := s.trips[id]
	if !ok {
		return nil, domain.ErrTripNotFound
	}
	return trip, nil
}

func (s *stubRepo) UpdateTripStatus(id string, status domain.TripStatus) error {
	trip, ok := s.trips[id]
	if !ok {
		return domain.ErrTripNotFound
	}
	s.statuses[id] = status
	trip.Status = status
	return nil
}

func (s *stubRepo) SetTripDriver(id string, driverID *string) error {
	trip, ok := s.trips[id]
	if !ok {
		return domain.ErrTripNotFound
	}
	trip.DriverID = driverID
	return nil
}

func (s *stubRepo) SaveLocation(tripID string, update domain.LocationUpdate) error {
	s.lastLocation = &update
	return nil
}

func (s *stubRepo) GetLatestLocation(tripID string) (*domain.LocationUpdate, error) {
	return s.lastLocation, nil
}

func (s *stubRepo) ListTrips(userID string, role string, limit, offset int) ([]*domain.Trip, int64, error) {
	items := make([]*domain.Trip, 0, len(s.trips))
	for _, trip := range s.trips {
		items = append(items, trip)
	}
	return items, int64(len(items)), nil
}

func TestTripServiceCreate(t *testing.T) {
	repo := newStubRepo()
	service := domain.NewTripService(repo)

	trip := &domain.Trip{
		RiderID:    "rider-1",
		ServiceID:  "UIT-Bike",
		OriginText: "Campus A",
		DestText:   "Campus B",
	}

	err := service.Create(context.Background(), trip)
	require.NoError(t, err)
	require.NotEmpty(t, trip.ID)
	require.Equal(t, domain.TripStatusRequested, trip.Status)
	require.WithinDuration(t, time.Now(), trip.CreatedAt, time.Second)
}

func TestTripServiceUpdateStatusValidation(t *testing.T) {
	repo := newStubRepo()
	service := domain.NewTripService(repo)

	err := service.UpdateStatus(context.Background(), "trip-1", domain.TripStatus("invalid"))
	require.ErrorIs(t, err, domain.ErrInvalidStatus)
}

func TestTripServiceRecordLocation(t *testing.T) {
	repo := newStubRepo()
	service := domain.NewTripService(repo)

	repo.trips["trip-1"] = &domain.Trip{ID: "trip-1"}

	update := domain.LocationUpdate{
		Latitude:  10.1,
		Longitude: 106.2,
		Timestamp: time.Now().UTC(),
	}
	err := service.RecordLocation(context.Background(), "trip-1", update)
	require.NoError(t, err)
	require.NotNil(t, repo.lastLocation)
	require.Equal(t, 10.1, repo.lastLocation.Latitude)
}
