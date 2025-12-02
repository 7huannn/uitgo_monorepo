package db

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"uitgo/backend/internal/domain"
)

type deviceTokenRepository struct {
	db *gorm.DB
}

// NewDeviceTokenRepository creates a repository backed by GORM.
func NewDeviceTokenRepository(db *gorm.DB) domain.DeviceTokenRepository {
	return &deviceTokenRepository{db: db}
}

type deviceTokenModel struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID    string    `gorm:"index"`
	Platform  string
	Token     string    `gorm:"uniqueIndex"`
	CreatedAt time.Time `gorm:"autoCreateTime"`
}

func (deviceTokenModel) TableName() string {
	return "device_tokens"
}

func (r *deviceTokenRepository) Register(ctx context.Context, userID, platform, token string) (*domain.DeviceToken, error) {
	token = strings.TrimSpace(token)
	platform = strings.TrimSpace(strings.ToLower(platform))
	if platform == "" {
		platform = "unknown"
	}

	var created deviceTokenModel
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("token = ?", token).Delete(&deviceTokenModel{}).Error; err != nil {
			return err
		}
		model := deviceTokenModel{
			ID:       uuid.New(),
			UserID:   userID,
			Platform: platform,
			Token:    token,
		}
		if err := tx.Create(&model).Error; err != nil {
			return err
		}
		created = model
		return nil
	})
	if err != nil {
		return nil, err
	}
	return toDeviceTokenDomain(created), nil
}

func (r *deviceTokenRepository) ListByUsers(ctx context.Context, userIDs []string) ([]*domain.DeviceToken, error) {
	if len(userIDs) == 0 {
		return []*domain.DeviceToken{}, nil
	}
	var models []deviceTokenModel
	if err := r.db.WithContext(ctx).
		Where("user_id IN ?", userIDs).
		Order("created_at DESC").
		Find(&models).Error; err != nil {
		return nil, err
	}
	tokens := make([]*domain.DeviceToken, 0, len(models))
	for _, model := range models {
		tokens = append(tokens, toDeviceTokenDomain(model))
	}
	return tokens, nil
}

func toDeviceTokenDomain(model deviceTokenModel) *domain.DeviceToken {
	return &domain.DeviceToken{
		ID:        model.ID.String(),
		UserID:    model.UserID,
		Platform:  model.Platform,
		Token:     model.Token,
		CreatedAt: model.CreatedAt,
	}
}
