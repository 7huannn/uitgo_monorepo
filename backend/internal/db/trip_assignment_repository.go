package db

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"uitgo/backend/internal/domain"
)

type tripAssignmentRepository struct {
	db *gorm.DB
}

// NewTripAssignmentRepository builds a repository for trip assignments.
func NewTripAssignmentRepository(db *gorm.DB) domain.TripAssignmentRepository {
	return &tripAssignmentRepository{db: db}
}

type tripAssignmentModel struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey"`
	TripID      uuid.UUID `gorm:"type:uuid;uniqueIndex"`
	DriverID    uuid.UUID `gorm:"type:uuid;index"`
	Status      string
	RespondedAt *time.Time
	CreatedAt   time.Time `gorm:"autoCreateTime"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime"`
}

func (tripAssignmentModel) TableName() string {
	return "trip_assignments"
}

func (r *tripAssignmentRepository) Assign(ctx context.Context, tripID, driverID string) (*domain.TripAssignment, error) {
	tripUID, err := uuid.Parse(tripID)
	if err != nil {
		return nil, err
	}
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	var existing tripAssignmentModel
	err = r.db.WithContext(ctx).First(&existing, "trip_id = ?", tripUID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		model := tripAssignmentModel{
			ID:        uuid.New(),
			TripID:    tripUID,
			DriverID:  driverUID,
			Status:    string(domain.TripAssignmentPending),
			CreatedAt: now,
			UpdatedAt: now,
		}
		if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
			return nil, err
		}
		return toTripAssignmentDomain(&model), nil
	}
	if err != nil {
		return nil, err
	}

	updates := map[string]any{
		"driver_id":    driverUID,
		"status":       string(domain.TripAssignmentPending),
		"responded_at": nil,
		"updated_at":   now,
	}
	res := r.db.WithContext(ctx).Model(&tripAssignmentModel{}).Where("trip_id = ?", tripUID).Updates(updates)
	if res.Error != nil {
		return nil, res.Error
	}
	if res.RowsAffected == 0 {
		return nil, domain.ErrTripAssignmentNotFound
	}

	if err := r.db.WithContext(ctx).First(&existing, "trip_id = ?", tripUID).Error; err != nil {
		return nil, err
	}
	return toTripAssignmentDomain(&existing), nil
}

func (r *tripAssignmentRepository) UpdateStatus(ctx context.Context, tripID, driverID string, status domain.TripAssignmentStatus, respondedAt *time.Time) (*domain.TripAssignment, error) {
	tripUID, err := uuid.Parse(tripID)
	if err != nil {
		return nil, err
	}
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	updatePayload := map[string]any{
		"status":     string(status),
		"updated_at": now,
	}
	if respondedAt != nil {
		updatePayload["responded_at"] = *respondedAt
	} else if status == domain.TripAssignmentPending {
		updatePayload["responded_at"] = nil
	} else {
		ts := now
		updatePayload["responded_at"] = ts
		respondedAt = &ts
	}
	res := r.db.WithContext(ctx).Model(&tripAssignmentModel{}).
		Where("trip_id = ? AND driver_id = ?", tripUID, driverUID).
		Updates(updatePayload)
	if res.Error != nil {
		return nil, res.Error
	}
	if res.RowsAffected == 0 {
		return nil, domain.ErrTripAssignmentNotFound
	}
	var model tripAssignmentModel
	if err := r.db.WithContext(ctx).First(&model, "trip_id = ?", tripUID).Error; err != nil {
		return nil, err
	}
	return toTripAssignmentDomain(&model), nil
}

func (r *tripAssignmentRepository) GetByTripID(ctx context.Context, tripID string) (*domain.TripAssignment, error) {
	tripUID, err := uuid.Parse(tripID)
	if err != nil {
		return nil, err
	}
	var model tripAssignmentModel
	if err := r.db.WithContext(ctx).First(&model, "trip_id = ?", tripUID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return toTripAssignmentDomain(&model), nil
}

func (r *tripAssignmentRepository) FindActiveByDriver(ctx context.Context, driverID string) (*domain.TripAssignment, error) {
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	var model tripAssignmentModel
	if err := r.db.WithContext(ctx).
		Where("driver_id = ? AND status IN ?", driverUID, []string{string(domain.TripAssignmentPending), string(domain.TripAssignmentAccepted)}).
		Order("updated_at DESC").
		First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return toTripAssignmentDomain(&model), nil
}

func (r *tripAssignmentRepository) Clear(ctx context.Context, tripID string) error {
	tripUID, err := uuid.Parse(tripID)
	if err != nil {
		return err
	}
	res := r.db.WithContext(ctx).Where("trip_id = ?", tripUID).Delete(&tripAssignmentModel{})
	if res.Error != nil {
		return res.Error
	}
	return nil
}

// ClearAll removes every assignment (dev/demo cleanup).
func (r *tripAssignmentRepository) ClearAll(ctx context.Context) error {
	if r.db == nil {
		return errors.New("db not configured")
	}
	return r.db.WithContext(ctx).Exec("DELETE FROM trip_assignments").Error
}

func toTripAssignmentDomain(model *tripAssignmentModel) *domain.TripAssignment {
	if model == nil {
		return nil
	}
	return &domain.TripAssignment{
		ID:          model.ID.String(),
		TripID:      model.TripID.String(),
		DriverID:    model.DriverID.String(),
		Status:      domain.TripAssignmentStatus(model.Status),
		RespondedAt: model.RespondedAt,
		CreatedAt:   model.CreatedAt,
		UpdatedAt:   model.UpdatedAt,
	}
}
