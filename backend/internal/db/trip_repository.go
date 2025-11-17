package db

import (
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"uitgo/backend/internal/domain"
)

type tripRepository struct {
	db *gorm.DB
}

var (
	_ domain.TripRepository     = (*tripRepository)(nil)
	_ domain.TripSyncRepository = (*tripRepository)(nil)
)

// NewTripRepository returns a GORM-backed TripRepository.
func NewTripRepository(db *gorm.DB) domain.TripRepository {
	return &tripRepository{db: db}
}

type tripModel struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey"`
	RiderID    string
	DriverID   *string
	ServiceID  string
	OriginText string
	DestText   string
	OriginLat  *float64
	OriginLng  *float64
	DestLat    *float64
	DestLng    *float64
	Status     string
	CreatedAt  time.Time `gorm:"autoCreateTime"`
	UpdatedAt  time.Time `gorm:"autoUpdateTime"`
}

func (tripModel) TableName() string {
	return "trips"
}

type tripEventModel struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey"`
	TripID    uuid.UUID
	Type      string
	Payload   []byte    `gorm:"type:jsonb"`
	CreatedAt time.Time `gorm:"autoCreateTime"`
}

func (tripEventModel) TableName() string {
	return "trip_events"
}

func (r *tripRepository) CreateTrip(trip *domain.Trip) error {
	var id uuid.UUID
	if trip.ID != "" {
		parsed, err := uuid.Parse(trip.ID)
		if err != nil {
			return err
		}
		id = parsed
	} else {
		id = uuid.New()
	}

	now := trip.CreatedAt
	if now.IsZero() {
		now = time.Now().UTC()
	}
	model := tripModel{
		ID:         id,
		RiderID:    trip.RiderID,
		DriverID:   trip.DriverID,
		ServiceID:  trip.ServiceID,
		OriginText: trip.OriginText,
		DestText:   trip.DestText,
		OriginLat:  trip.OriginLat,
		OriginLng:  trip.OriginLng,
		DestLat:    trip.DestLat,
		DestLng:    trip.DestLng,
		Status:     string(trip.Status),
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	if err := r.db.Create(&model).Error; err != nil {
		return err
	}

	trip.ID = model.ID.String()
	trip.CreatedAt = model.CreatedAt
	trip.UpdatedAt = model.UpdatedAt
	return nil
}

func (r *tripRepository) GetTrip(id string) (*domain.Trip, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, err
	}

	var model tripModel
	if err := r.db.First(&model, "id = ?", uid).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrTripNotFound
		}
		return nil, err
	}

	return &domain.Trip{
		ID:         model.ID.String(),
		RiderID:    model.RiderID,
		DriverID:   model.DriverID,
		ServiceID:  model.ServiceID,
		OriginText: model.OriginText,
		DestText:   model.DestText,
		OriginLat:  model.OriginLat,
		OriginLng:  model.OriginLng,
		DestLat:    model.DestLat,
		DestLng:    model.DestLng,
		Status:     domain.TripStatus(model.Status),
		CreatedAt:  model.CreatedAt,
		UpdatedAt:  model.UpdatedAt,
	}, nil
}

func (r *tripRepository) UpdateTripStatus(id string, status domain.TripStatus) error {
	uid, err := uuid.Parse(id)
	if err != nil {
		return err
	}

	res := r.db.Model(&tripModel{}).Where("id = ?", uid).
		Updates(map[string]any{
			"status":     string(status),
			"updated_at": time.Now().UTC(),
		})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return domain.ErrTripNotFound
	}
	return nil
}

func (r *tripRepository) SetTripDriver(id string, driverID *string) error {
	uid, err := uuid.Parse(id)
	if err != nil {
		return err
	}
	var driverValue any
	if driverID == nil || *driverID == "" {
		driverValue = nil
	} else {
		if _, err := uuid.Parse(*driverID); err != nil {
			return err
		}
		driverValue = *driverID
	}
	res := r.db.Model(&tripModel{}).Where("id = ?", uid).Updates(map[string]any{
		"driver_id":  driverValue,
		"updated_at": time.Now().UTC(),
	})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return domain.ErrTripNotFound
	}
	return nil
}

func (r *tripRepository) SaveLocation(tripID string, update domain.LocationUpdate) error {
	uid, err := uuid.Parse(tripID)
	if err != nil {
		return err
	}

	if update.Timestamp.IsZero() {
		update.Timestamp = time.Now().UTC()
	}

	payload, err := json.Marshal(update)
	if err != nil {
		return err
	}

	event := tripEventModel{
		ID:        uuid.New(),
		TripID:    uid,
		Type:      "location",
		Payload:   payload,
		CreatedAt: update.Timestamp,
	}

	if err := r.db.Create(&event).Error; err != nil {
		return err
	}

	return nil
}

func (r *tripRepository) GetLatestLocation(tripID string) (*domain.LocationUpdate, error) {
	uid, err := uuid.Parse(tripID)
	if err != nil {
		return nil, err
	}

	var event tripEventModel
	err = r.db.
		Where("trip_id = ? AND type = ?", uid, "location").
		Order("created_at DESC").
		First(&event).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}

	var update domain.LocationUpdate
	if err := json.Unmarshal(event.Payload, &update); err != nil {
		return nil, err
	}
	if update.Timestamp.IsZero() {
		update.Timestamp = event.CreatedAt
	}

	return &update, nil
}

func (r *tripRepository) ListTrips(userID string, role string, limit, offset int) ([]*domain.Trip, int64, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	query := r.db.Model(&tripModel{})
	switch role {
	case "driver":
		uid, err := uuid.Parse(userID)
		if err != nil {
			return nil, 0, domain.ErrDriverNotFound
		}
		var driver driverModel
		if err := r.db.Select("id").First(&driver, "user_id = ?", uid).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return []*domain.Trip{}, 0, nil
			}
			return nil, 0, err
		}
		query = query.Where("driver_id = ?", driver.ID.String())
	default:
		query = query.Where("rider_id = ?", userID)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var models []tripModel
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&models).Error; err != nil {
		return nil, 0, err
	}

	trips := make([]*domain.Trip, 0, len(models))
	for _, model := range models {
		trip := &domain.Trip{
			ID:         model.ID.String(),
			RiderID:    model.RiderID,
			DriverID:   model.DriverID,
			ServiceID:  model.ServiceID,
			OriginText: model.OriginText,
			DestText:   model.DestText,
			OriginLat:  model.OriginLat,
			OriginLng:  model.OriginLng,
			DestLat:    model.DestLat,
			DestLng:    model.DestLng,
			Status:     domain.TripStatus(model.Status),
			CreatedAt:  model.CreatedAt,
			UpdatedAt:  model.UpdatedAt,
		}
		trips = append(trips, trip)
	}

	return trips, total, nil
}
