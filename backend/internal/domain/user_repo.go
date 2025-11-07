package domain

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// UserRepository persists and fetches users.
type UserRepository interface {
	Create(ctx context.Context, user *User) error
	FindByEmail(ctx context.Context, email string) (*User, error)
}

// NewUserRepository returns a GORM-backed user repository.
func NewUserRepository(db *gorm.DB) UserRepository {
	return &gormUserRepository{db: db}
}

type userModel struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey"`
	Name         string
	Email        string `gorm:"uniqueIndex"`
	Phone        string
	PasswordHash string
	CreatedAt    time.Time `gorm:"autoCreateTime"`
}

func (userModel) TableName() string {
	return "users"
}

type gormUserRepository struct {
	db *gorm.DB
}

func (r *gormUserRepository) Create(ctx context.Context, user *User) error {
	id := uuid.New()
	now := time.Now().UTC()

	model := userModel{
		ID:           id,
		Name:         user.Name,
		Email:        strings.ToLower(user.Email),
		Phone:        user.Phone,
		PasswordHash: user.PasswordHash,
		CreatedAt:    now,
	}

	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return err
	}

	user.ID = model.ID.String()
	user.CreatedAt = model.CreatedAt
	return nil
}

func (r *gormUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	var model userModel
	if err := r.db.WithContext(ctx).
		Where("LOWER(email) = ?", strings.ToLower(email)).
		First(&model).Error; err != nil {
		return nil, err
	}

	return &User{
		ID:           model.ID.String(),
		Name:         model.Name,
		Email:        model.Email,
		Phone:        model.Phone,
		PasswordHash: model.PasswordHash,
		CreatedAt:    model.CreatedAt,
	}, nil
}
