package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RefreshToken represents a persisted refresh token.
type RefreshToken struct {
	ID              string
	UserID          string
	TokenHash       string
	TokenCiphertext []byte
	CreatedAt       time.Time
	ExpiresAt       time.Time
	RevokedAt       *time.Time
}

// RefreshTokenRepository persists refresh tokens for session management.
type RefreshTokenRepository interface {
	Create(ctx context.Context, token *RefreshToken) error
	FindActiveByHash(ctx context.Context, hash string) (*RefreshToken, error)
	Revoke(ctx context.Context, id string) error
	RevokeAllForUser(ctx context.Context, userID string) error
}

// NewRefreshTokenRepository returns a GORM-backed refresh token store.
func NewRefreshTokenRepository(db *gorm.DB) RefreshTokenRepository {
	return &gormRefreshTokenRepository{db: db}
}

type refreshTokenModel struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID          uuid.UUID `gorm:"type:uuid;not null"`
	TokenHash       string    `gorm:"uniqueIndex"`
	TokenCiphertext []byte    `gorm:"column:token_ciphertext"`
	CreatedAt       time.Time `gorm:"autoCreateTime"`
	ExpiresAt       time.Time
	RevokedAt       *time.Time
}

func (refreshTokenModel) TableName() string {
	return "refresh_tokens"
}

type gormRefreshTokenRepository struct {
	db *gorm.DB
}

func (r *gormRefreshTokenRepository) Create(ctx context.Context, token *RefreshToken) error {
	userID, err := uuid.Parse(token.UserID)
	if err != nil {
		return err
	}
	model := refreshTokenModel{
		ID:              uuid.New(),
		UserID:          userID,
		TokenHash:       token.TokenHash,
		TokenCiphertext: token.TokenCiphertext,
		ExpiresAt:       token.ExpiresAt.UTC(),
	}
	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return err
	}
	token.ID = model.ID.String()
	token.CreatedAt = model.CreatedAt
	return nil
}

func (r *gormRefreshTokenRepository) FindActiveByHash(ctx context.Context, hash string) (*RefreshToken, error) {
	var model refreshTokenModel
	err := r.db.WithContext(ctx).
		Where("token_hash = ? AND (revoked_at IS NULL) AND expires_at > NOW()", hash).
		First(&model).Error
	if err != nil {
		return nil, err
	}
	return &RefreshToken{
		ID:              model.ID.String(),
		UserID:          model.UserID.String(),
		TokenHash:       model.TokenHash,
		TokenCiphertext: append([]byte{}, model.TokenCiphertext...),
		CreatedAt:       model.CreatedAt,
		ExpiresAt:       model.ExpiresAt,
		RevokedAt:       model.RevokedAt,
	}, nil
}

func (r *gormRefreshTokenRepository) Revoke(ctx context.Context, id string) error {
	tokenID, err := uuid.Parse(id)
	if err != nil {
		return gorm.ErrRecordNotFound
	}
	now := time.Now().UTC()
	res := r.db.WithContext(ctx).
		Model(&refreshTokenModel{}).
		Where("id = ?", tokenID).
		Updates(map[string]any{
			"revoked_at": now,
		})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *gormRefreshTokenRepository) RevokeAllForUser(ctx context.Context, userID string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return gorm.ErrRecordNotFound
	}
	now := time.Now().UTC()
	return r.db.WithContext(ctx).
		Model(&refreshTokenModel{}).
		Where("user_id = ?", uid).
		Update("revoked_at", now).Error
}
