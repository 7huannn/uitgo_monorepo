package db

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"uitgo/backend/internal/domain"
)

type driverRepository struct {
	db *gorm.DB
}

// NewDriverRepository returns a GORM backed driver repository.
func NewDriverRepository(db *gorm.DB) domain.DriverRepository {
	return &driverRepository{db: db}
}

type driverModel struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID        uuid.UUID `gorm:"type:uuid;uniqueIndex"`
	FullName      string
	Phone         string
	LicenseNumber string
	AvatarURL     *string
	Rating        float64
	CreatedAt     time.Time     `gorm:"autoCreateTime"`
	UpdatedAt     time.Time     `gorm:"autoUpdateTime"`
	Vehicle       *vehicleModel `gorm:"foreignKey:DriverID"`
}

func (driverModel) TableName() string {
	return "drivers"
}

type vehicleModel struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey"`
	DriverID    uuid.UUID `gorm:"type:uuid;uniqueIndex"`
	Make        string
	Model       string
	Color       string
	Year        int
	PlateNumber string
	CreatedAt   time.Time `gorm:"autoCreateTime"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime"`
}

func (vehicleModel) TableName() string {
	return "vehicles"
}

type driverStatusModel struct {
	DriverID  uuid.UUID `gorm:"type:uuid;primaryKey"`
	Status    string
	UpdatedAt time.Time `gorm:"autoUpdateTime"`
}

func (driverStatusModel) TableName() string {
	return "driver_status"
}

type driverLocationModel struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey"`
	DriverID   uuid.UUID `gorm:"type:uuid;index"`
	Latitude   float64
	Longitude  float64
	Accuracy   *float64
	Heading    *float64
	Speed      *float64
	RecordedAt time.Time
}

func (driverLocationModel) TableName() string {
	return "driver_locations"
}

func (r *driverRepository) Create(ctx context.Context, driver *domain.Driver) error {
	if driver == nil {
		return errors.New("driver required")
	}
	userUID, err := uuid.Parse(driver.UserID)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	model := driverModel{
		ID:            uuid.New(),
		UserID:        userUID,
		FullName:      driver.FullName,
		Phone:         driver.Phone,
		LicenseNumber: driver.LicenseNumber,
		AvatarURL:     driver.AvatarURL,
		Rating:        driver.Rating,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
	if model.Rating == 0 {
		model.Rating = 5.0
	}
	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return domain.ErrDriverAlreadyExists
		}
		return err
	}
	driver.ID = model.ID.String()
	driver.CreatedAt = model.CreatedAt
	driver.UpdatedAt = model.UpdatedAt
	driver.Rating = model.Rating
	return nil
}

func (r *driverRepository) FindByID(ctx context.Context, id string) (*domain.Driver, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, domain.ErrDriverNotFound
	}
	var model driverModel
	if err := r.db.WithContext(ctx).
		Preload("Vehicle").
		First(&model, "id = ?", uid).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrDriverNotFound
		}
		return nil, err
	}
	return toDriverDomain(&model), nil
}

func (r *driverRepository) FindByUserID(ctx context.Context, userID string) (*domain.Driver, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, domain.ErrDriverNotFound
	}
	var model driverModel
	if err := r.db.WithContext(ctx).
		Preload("Vehicle").
		First(&model, "user_id = ?", uid).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrDriverNotFound
		}
		return nil, err
	}
	return toDriverDomain(&model), nil
}

func (r *driverRepository) Update(ctx context.Context, driver *domain.Driver) error {
	if driver == nil || driver.ID == "" {
		return errors.New("driver id required")
	}
	uid, err := uuid.Parse(driver.ID)
	if err != nil {
		return err
	}
	updates := map[string]any{
		"full_name":      driver.FullName,
		"phone":          driver.Phone,
		"license_number": driver.LicenseNumber,
		"avatar_url":     driver.AvatarURL,
		"updated_at":     time.Now().UTC(),
	}
	res := r.db.WithContext(ctx).Model(&driverModel{}).Where("id = ?", uid).Updates(updates)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return domain.ErrDriverNotFound
	}
	return nil
}

func (r *driverRepository) SaveVehicle(ctx context.Context, vehicle *domain.Vehicle) (*domain.Vehicle, error) {
	if vehicle == nil || vehicle.DriverID == "" {
		return nil, errors.New("vehicle driver id required")
	}
	driverUID, err := uuid.Parse(vehicle.DriverID)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	var existing vehicleModel
	err = r.db.WithContext(ctx).Where("driver_id = ?", driverUID).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		model := vehicleModel{
			ID:          uuid.New(),
			DriverID:    driverUID,
			Make:        vehicle.Make,
			Model:       vehicle.Model,
			Color:       vehicle.Color,
			Year:        vehicle.Year,
			PlateNumber: vehicle.PlateNumber,
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
			return nil, err
		}
		return toVehicleDomain(&model), nil
	}
	if err != nil {
		return nil, err
	}
	updates := map[string]any{
		"make":         vehicle.Make,
		"model":        vehicle.Model,
		"color":        vehicle.Color,
		"year":         vehicle.Year,
		"plate_number": vehicle.PlateNumber,
		"updated_at":   now,
	}
	if err := r.db.WithContext(ctx).Model(&vehicleModel{}).
		Where("driver_id = ?", driverUID).
		Updates(updates).Error; err != nil {
		return nil, err
	}
	if err := r.db.WithContext(ctx).Where("driver_id = ?", driverUID).First(&existing).Error; err != nil {
		return nil, err
	}
	return toVehicleDomain(&existing), nil
}

func (r *driverRepository) FindVehicle(ctx context.Context, driverID string) (*domain.Vehicle, error) {
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	var model vehicleModel
	if err := r.db.WithContext(ctx).First(&model, "driver_id = ?", driverUID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return toVehicleDomain(&model), nil
}

func (r *driverRepository) SetAvailability(ctx context.Context, driverID string, availability domain.DriverAvailability) (*domain.DriverStatus, error) {
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	model := driverStatusModel{
		DriverID:  driverUID,
		Status:    string(availability),
		UpdatedAt: now,
	}
	if err := r.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "driver_id"}},
		DoUpdates: clause.Assignments(map[string]any{"status": model.Status, "updated_at": model.UpdatedAt}),
	}).Create(&model).Error; err != nil {
		return nil, err
	}
	return &domain.DriverStatus{
		DriverID:     driverID,
		Availability: availability,
		UpdatedAt:    now,
	}, nil
}

func (r *driverRepository) GetAvailability(ctx context.Context, driverID string) (*domain.DriverStatus, error) {
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	var model driverStatusModel
	if err := r.db.WithContext(ctx).First(&model, "driver_id = ?", driverUID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &domain.DriverStatus{
		DriverID:     driverID,
		Availability: domain.DriverAvailability(model.Status),
		UpdatedAt:    model.UpdatedAt,
	}, nil
}

func (r *driverRepository) RecordLocation(ctx context.Context, driverID string, location *domain.DriverLocation) error {
	if location == nil {
		return errors.New("location required")
	}
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return err
	}
	recordedAt := location.RecordedAt
	if recordedAt.IsZero() {
		recordedAt = time.Now().UTC()
	}
	model := driverLocationModel{
		ID:         uuid.New(),
		DriverID:   driverUID,
		Latitude:   location.Latitude,
		Longitude:  location.Longitude,
		Accuracy:   location.Accuracy,
		Heading:    location.Heading,
		Speed:      location.Speed,
		RecordedAt: recordedAt,
	}
	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return err
	}
	location.ID = model.ID.String()
	location.DriverID = driverID
	location.RecordedAt = recordedAt
	return nil
}

func (r *driverRepository) LatestLocation(ctx context.Context, driverID string) (*domain.DriverLocation, error) {
	driverUID, err := uuid.Parse(driverID)
	if err != nil {
		return nil, err
	}
	var model driverLocationModel
	if err := r.db.WithContext(ctx).
		Order("recorded_at DESC").
		First(&model, "driver_id = ?", driverUID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return toDriverLocationDomain(&model), nil
}

func toDriverDomain(model *driverModel) *domain.Driver {
	if model == nil {
		return nil
	}
	driver := &domain.Driver{
		ID:            model.ID.String(),
		UserID:        model.UserID.String(),
		FullName:      model.FullName,
		Phone:         model.Phone,
		LicenseNumber: model.LicenseNumber,
		AvatarURL:     model.AvatarURL,
		Rating:        model.Rating,
		CreatedAt:     model.CreatedAt,
		UpdatedAt:     model.UpdatedAt,
	}
	if model.Vehicle != nil {
		driver.Vehicle = toVehicleDomain(model.Vehicle)
	}
	return driver
}

func toVehicleDomain(model *vehicleModel) *domain.Vehicle {
	if model == nil {
		return nil
	}
	return &domain.Vehicle{
		ID:          model.ID.String(),
		DriverID:    model.DriverID.String(),
		Make:        model.Make,
		Model:       model.Model,
		Color:       model.Color,
		Year:        model.Year,
		PlateNumber: model.PlateNumber,
		CreatedAt:   model.CreatedAt,
		UpdatedAt:   model.UpdatedAt,
	}
}

func toDriverLocationDomain(model *driverLocationModel) *domain.DriverLocation {
	if model == nil {
		return nil
	}
	return &domain.DriverLocation{
		ID:         model.ID.String(),
		DriverID:   model.DriverID.String(),
		Latitude:   model.Latitude,
		Longitude:  model.Longitude,
		Accuracy:   model.Accuracy,
		Heading:    model.Heading,
		Speed:      model.Speed,
		RecordedAt: model.RecordedAt,
	}
}
