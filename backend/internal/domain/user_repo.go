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
	FindByID(ctx context.Context, id string) (*User, error)
	UpdateProfile(ctx context.Context, id string, name *string, phone *string) (*User, error)
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

func (r *gormUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, gorm.ErrRecordNotFound
	}

	var model userModel
	if err := r.db.WithContext(ctx).First(&model, "id = ?", uid).Error; err != nil {
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

func (r *gormUserRepository) UpdateProfile(ctx context.Context, id string, name *string, phone *string) (*User, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, gorm.ErrRecordNotFound
	}

	updates := map[string]any{}
	if name != nil {
		trimmed := strings.TrimSpace(*name)
		if trimmed != "" {
			updates["name"] = trimmed
		}
	}
	if phone != nil {
		trimmed := strings.TrimSpace(*phone)
		if trimmed != "" {
			updates["phone"] = trimmed
		} else {
			updates["phone"] = nil
		}
	}

	if len(updates) > 0 {
		res := r.db.WithContext(ctx).Model(&userModel{}).Where("id = ?", uid).Updates(updates)
		if res.Error != nil {
			return nil, res.Error
		}
		if res.RowsAffected == 0 {
			return nil, gorm.ErrRecordNotFound
		}
	}

	return r.FindByID(ctx, id)
}
