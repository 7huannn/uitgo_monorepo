package domain

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"
)

// DriverRegistrationInput captures required fields for onboarding.
type DriverRegistrationInput struct {
	FullName      string
	Phone         string
	LicenseNumber string
	AvatarURL     *string
	Vehicle       *Vehicle
}

// DriverProfileUpdate wraps optional fields for profile edits.
type DriverProfileUpdate struct {
	FullName      *string
	Phone         *string
	LicenseNumber *string
	AvatarURL     *string
	Vehicle       *Vehicle
}

// DriverService orchestrates driver onboarding and dispatch workflows.
type DriverService struct {
	drivers     DriverRepository
	assignments TripAssignmentRepository
	trips       TripSyncRepository
	notifier    TripEventNotifier
}

// NewDriverService wires repositories for driver operations.
func NewDriverService(drivers DriverRepository, assignments TripAssignmentRepository, trips TripSyncRepository, notifier TripEventNotifier) *DriverService {
	return &DriverService{
		drivers:     drivers,
		assignments: assignments,
		trips:       trips,
		notifier:    notifier,
	}
}

// Register creates a driver profile for the authenticated user.
func (s *DriverService) Register(ctx context.Context, userID string, input DriverRegistrationInput) (*Driver, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	fullName := strings.TrimSpace(input.FullName)
	if fullName == "" {
		return nil, errors.New("full name required")
	}
	if existing, err := s.drivers.FindByUserID(ctx, userID); err == nil && existing != nil {
		return nil, ErrDriverAlreadyExists
	} else if err != nil && err != ErrDriverNotFound {
		return nil, err
	}

	driver := &Driver{
		UserID:        userID,
		FullName:      fullName,
		Phone:         strings.TrimSpace(input.Phone),
		LicenseNumber: strings.TrimSpace(input.LicenseNumber),
		AvatarURL:     input.AvatarURL,
		Rating:        5.0,
	}

	if err := s.drivers.Create(ctx, driver); err != nil {
		return nil, err
	}

	if input.Vehicle != nil {
		input.Vehicle.DriverID = driver.ID
		if vehicle, err := s.drivers.SaveVehicle(ctx, sanitizeVehicle(input.Vehicle)); err == nil {
			driver.Vehicle = vehicle
		} else {
			return nil, err
		}
	}

	if status, err := s.drivers.SetAvailability(ctx, driver.ID, DriverOffline); err == nil {
		driver.Status = status
	}

	return driver, nil
}

// Me returns the driver profile bound to the user.
func (s *DriverService) Me(ctx context.Context, userID string) (*Driver, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	driver, err := s.drivers.FindByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	enrichDriver(ctx, s.drivers, driver)
	return driver, nil
}

// UpdateProfile patches driver info and vehicle details.
func (s *DriverService) UpdateProfile(ctx context.Context, userID string, updates DriverProfileUpdate) (*Driver, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	driver, err := s.drivers.FindByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	if updates.FullName != nil {
		if trimmed := strings.TrimSpace(*updates.FullName); trimmed != "" {
			driver.FullName = trimmed
		}
	}
	if updates.Phone != nil {
		driver.Phone = strings.TrimSpace(*updates.Phone)
	}
	if updates.LicenseNumber != nil {
		driver.LicenseNumber = strings.TrimSpace(*updates.LicenseNumber)
	}
	if updates.AvatarURL != nil {
		driver.AvatarURL = updates.AvatarURL
	}

	if err := s.drivers.Update(ctx, driver); err != nil {
		return nil, err
	}

	if updates.Vehicle != nil {
		updates.Vehicle.DriverID = driver.ID
		vehicle, err := s.drivers.SaveVehicle(ctx, sanitizeVehicle(updates.Vehicle))
		if err != nil {
			return nil, err
		}
		driver.Vehicle = vehicle
	} else if driver.Vehicle == nil {
		driver.Vehicle, _ = s.drivers.FindVehicle(ctx, driver.ID)
	}

	enrichDriver(ctx, s.drivers, driver)
	return driver, nil
}

// UpdateAvailability toggles driver online/offline.
func (s *DriverService) UpdateAvailability(ctx context.Context, driverID string, availability DriverAvailability) (*DriverStatus, error) {
	if driverID == "" {
		return nil, errors.New("driver id required")
	}
	if availability != DriverOnline && availability != DriverOffline {
		return nil, errors.New("invalid availability")
	}
	if _, err := s.drivers.FindByID(ctx, driverID); err != nil {
		return nil, err
	}
	return s.drivers.SetAvailability(ctx, driverID, availability)
}

// FindAvailableDriver returns the next online driver without an active assignment.
func (s *DriverService) FindAvailableDriver(ctx context.Context) (*Driver, error) {
	driver, err := s.drivers.FindAvailable(ctx)
	if err != nil {
		return nil, err
	}
	if driver == nil {
		return nil, ErrNoDriversAvailable
	}
	enrichDriver(ctx, s.drivers, driver)
	return driver, nil
}

// AssignNextAvailableDriver finds an available driver and assigns the trip.
func (s *DriverService) AssignNextAvailableDriver(ctx context.Context, tripID string) (*Driver, error) {
	driver, err := s.FindAvailableDriver(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := s.AssignTrip(ctx, tripID, driver.ID); err != nil {
		return nil, err
	}
	return driver, nil
}

// AssignTrip links a driver to a trip and creates/updates assignment row.
func (s *DriverService) AssignTrip(ctx context.Context, tripID, driverID string) (*TripAssignment, error) {
	if tripID == "" || driverID == "" {
		return nil, errors.New("trip id and driver id required")
	}
	trip, err := s.trips.GetTrip(tripID)
	if err != nil {
		return nil, err
	}
	driver, err := s.drivers.FindByID(ctx, driverID)
	if err != nil {
		return nil, err
	}
	status, err := s.drivers.GetAvailability(ctx, driverID)
	if err != nil {
		return nil, err
	}
	if status == nil || status.Availability != DriverOnline {
		return nil, ErrDriverOffline
	}
	if active, err := s.assignments.FindActiveByDriver(ctx, driverID); err != nil {
		return nil, err
	} else if active != nil && active.TripID != tripID && active.Status != TripAssignmentDeclined && active.Status != TripAssignmentCancelled {
		return nil, ErrAssignmentConflict
	}

	assignment, err := s.assignments.Assign(ctx, tripID, driverID)
	if err != nil {
		return nil, err
	}
	if err := s.trips.SetTripDriver(tripID, &driverID); err != nil {
		return nil, err
	}
	if s.notifier != nil {
		if err := s.notifier.NotifyDriverTripAssigned(ctx, driver, trip); err != nil {
			log.Printf("notify driver assignment: %v", err)
		}
	}
	return assignment, nil
}

// AcceptTrip marks the assignment accepted and updates trip status.
func (s *DriverService) AcceptTrip(ctx context.Context, tripID, driverID string) (*TripAssignment, error) {
	now := time.Now().UTC()
	assignment, err := s.assignments.UpdateStatus(ctx, tripID, driverID, TripAssignmentAccepted, &now)
	if err != nil {
		return nil, err
	}
	if err := s.trips.UpdateTripStatus(tripID, TripStatusAccepted); err != nil {
		return nil, err
	}
	return assignment, nil
}

// DeclineTrip releases the driver from the assignment.
func (s *DriverService) DeclineTrip(ctx context.Context, tripID, driverID string) (*TripAssignment, error) {
	now := time.Now().UTC()
	assignment, err := s.assignments.UpdateStatus(ctx, tripID, driverID, TripAssignmentDeclined, &now)
	if err != nil {
		return nil, err
	}
	if err := s.trips.SetTripDriver(tripID, nil); err != nil {
		return nil, err
	}
	return assignment, nil
}

// UpdateTripStatus allows drivers to move trip through arriving/in_ride/completed/cancelled.
func (s *DriverService) UpdateTripStatus(ctx context.Context, tripID, driverID string, next TripStatus) (*Trip, error) {
	if next != TripStatusArriving && next != TripStatusInRide && next != TripStatusCompleted && next != TripStatusCancelled {
		return nil, ErrInvalidStatus
	}
	trip, err := s.trips.GetTrip(tripID)
	if err != nil {
		return nil, err
	}
	if trip.DriverID == nil || *trip.DriverID != driverID {
		return nil, ErrTripAssignmentNotFound
	}
	if !allowedDriverTransition(trip.Status, next) {
		return nil, ErrInvalidStatus
	}
	assignment, err := s.assignments.GetByTripID(ctx, tripID)
	if err != nil {
		return nil, err
	}
	if assignment == nil || assignment.DriverID != driverID {
		return nil, ErrTripAssignmentNotFound
	}
	if next != TripStatusCancelled && assignment.Status != TripAssignmentAccepted {
		return nil, ErrInvalidStatus
	}

	if err := s.trips.UpdateTripStatus(tripID, next); err != nil {
		return nil, err
	}

	if next == TripStatusCompleted || next == TripStatusCancelled {
		_, _ = s.assignments.UpdateStatus(ctx, tripID, driverID, TripAssignmentCancelled, nil)
	}

	trip.Status = next
	if s.notifier != nil {
		if err := s.notifier.NotifyRiderStatusChange(ctx, trip, next); err != nil {
			log.Printf("notify rider status: %v", err)
		}
	}
	return trip, nil
}

func enrichDriver(ctx context.Context, repo DriverRepository, driver *Driver) {
	if driver == nil {
		return
	}
	if status, err := repo.GetAvailability(ctx, driver.ID); err == nil && status != nil {
		driver.Status = status
	}
	if location, err := repo.LatestLocation(ctx, driver.ID); err == nil && location != nil {
		driver.Location = location
	}
}

func sanitizeVehicle(vehicle *Vehicle) *Vehicle {
	if vehicle == nil {
		return nil
	}
	clone := *vehicle
	clone.Make = strings.TrimSpace(clone.Make)
	clone.Model = strings.TrimSpace(clone.Model)
	clone.Color = strings.TrimSpace(clone.Color)
	clone.PlateNumber = strings.ToUpper(strings.TrimSpace(clone.PlateNumber))
	return &clone
}

func allowedDriverTransition(current, next TripStatus) bool {
	switch current {
	case TripStatusAccepted:
		return next == TripStatusArriving || next == TripStatusCancelled
	case TripStatusArriving:
		return next == TripStatusInRide || next == TripStatusCancelled
	case TripStatusInRide:
		return next == TripStatusCompleted || next == TripStatusCancelled
	case TripStatusRequested:
		return next == TripStatusCancelled
	case TripStatusCancelled, TripStatusCompleted:
		return false
	default:
		return false
	}
}
