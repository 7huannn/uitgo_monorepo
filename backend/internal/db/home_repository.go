package db

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"uitgo/backend/internal/domain"
)

// Saved places repository --------------------------------------------------

type savedPlaceRepository struct {
	db *gorm.DB
}

// NewSavedPlaceRepository wires CRUD operations for saved_places table.
func NewSavedPlaceRepository(db *gorm.DB) domain.SavedPlaceRepository {
	return &savedPlaceRepository{db: db}
}

type savedPlaceModel struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID    string    `gorm:"index"`
	Name      string
	Address   string
	Latitude  float64
	Longitude float64
	CreatedAt time.Time `gorm:"autoCreateTime"`
	UpdatedAt time.Time `gorm:"autoUpdateTime"`
}

func (savedPlaceModel) TableName() string {
	return "saved_places"
}

func (r *savedPlaceRepository) List(ctx context.Context, userID string) ([]*domain.SavedPlace, error) {
	var rows []savedPlaceModel
	if err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC").
		Find(&rows).Error; err != nil {
		return nil, err
	}

	items := make([]*domain.SavedPlace, 0, len(rows))
	for _, row := range rows {
		items = append(items, &domain.SavedPlace{
			ID:        row.ID.String(),
			UserID:    row.UserID,
			Name:      row.Name,
			Address:   row.Address,
			Latitude:  row.Latitude,
			Longitude: row.Longitude,
			CreatedAt: row.CreatedAt,
			UpdatedAt: row.UpdatedAt,
		})
	}
	return items, nil
}

func (r *savedPlaceRepository) Create(ctx context.Context, place *domain.SavedPlace) error {
	var id uuid.UUID
	var err error
	if place.ID != "" {
		id, err = uuid.Parse(place.ID)
		if err != nil {
			return err
		}
	} else {
		id = uuid.New()
	}

	model := savedPlaceModel{
		ID:        id,
		UserID:    place.UserID,
		Name:      place.Name,
		Address:   place.Address,
		Latitude:  place.Latitude,
		Longitude: place.Longitude,
		CreatedAt: place.CreatedAt,
		UpdatedAt: place.UpdatedAt,
	}

	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return err
	}
	place.ID = model.ID.String()
	place.CreatedAt = model.CreatedAt
	place.UpdatedAt = model.UpdatedAt
	return nil
}

func (r *savedPlaceRepository) Delete(ctx context.Context, userID, id string) error {
	uid, err := uuid.Parse(id)
	if err != nil {
		return domain.ErrSavedPlaceNotFound
	}

	res := r.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", uid, userID).
		Delete(&savedPlaceModel{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return domain.ErrSavedPlaceNotFound
	}
	return nil
}

// Promotions repository ----------------------------------------------------

type promotionRepository struct {
	db *gorm.DB
}

// NewPromotionRepository wires promotion accessors.
func NewPromotionRepository(db *gorm.DB) domain.PromotionRepository {
	return &promotionRepository{db: db}
}

type promotionModel struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey"`
	Title         string
	Description   string
	Code          string
	ImageURL      *string
	GradientStart string
	GradientEnd   string
	ExpiresAt     *time.Time
	Priority      int
	IsActive      bool
	CreatedAt     time.Time `gorm:"autoCreateTime"`
}

func (promotionModel) TableName() string {
	return "promotions"
}

func (r *promotionRepository) ListActive(ctx context.Context) ([]*domain.Promotion, error) {
	var rows []promotionModel
	if err := r.db.WithContext(ctx).
		Where("is_active = ?", true).
		Order("priority DESC, created_at DESC").
		Find(&rows).Error; err != nil {
		return nil, err
	}

	items := make([]*domain.Promotion, 0, len(rows))
	for _, row := range rows {
		items = append(items, &domain.Promotion{
			ID:            row.ID.String(),
			Title:         row.Title,
			Description:   row.Description,
			Code:          row.Code,
			ImageURL:      row.ImageURL,
			GradientStart: row.GradientStart,
			GradientEnd:   row.GradientEnd,
			ExpiresAt:     row.ExpiresAt,
			Priority:      row.Priority,
		})
	}
	return items, nil
}

// News repository ----------------------------------------------------------

type newsRepository struct {
	db *gorm.DB
}

// NewNewsRepository wires news access.
func NewNewsRepository(db *gorm.DB) domain.NewsRepository {
	return &newsRepository{db: db}
}

type newsModel struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey"`
	Title       string
	Body        string
	Category    string
	Icon        string
	PublishedAt time.Time `gorm:"autoCreateTime"`
}

func (newsModel) TableName() string {
	return "news_items"
}

func (r *newsRepository) ListLatest(ctx context.Context, limit int) ([]*domain.NewsItem, error) {
	if limit <= 0 || limit > 50 {
		limit = 10
	}
	var rows []newsModel
	if err := r.db.WithContext(ctx).
		Order("published_at DESC").
		Limit(limit).
		Find(&rows).Error; err != nil {
		return nil, err
	}

	items := make([]*domain.NewsItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, &domain.NewsItem{
			ID:          row.ID.String(),
			Title:       row.Title,
			Body:        row.Body,
			Category:    row.Category,
			Icon:        row.Icon,
			PublishedAt: row.PublishedAt,
		})
	}
	return items, nil
}
