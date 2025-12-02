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
	List(ctx context.Context, role string, disabled *bool, q string, limit, offset int) ([]*User, int64, error)
	UpdateRoleAndStatus(ctx context.Context, id string, role *string, disabled *bool) (*User, error)
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
	Role         string    `gorm:"default:rider"`
	CreatedAt    time.Time `gorm:"autoCreateTime"`
	Disabled     bool      `gorm:"default:false"`
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
	role := strings.TrimSpace(strings.ToLower(user.Role))
	if role == "" {
		role = "rider"
	}

	model := userModel{
		ID:           id,
		Name:         user.Name,
		Email:        strings.ToLower(user.Email),
		Phone:        user.Phone,
		PasswordHash: user.PasswordHash,
		Role:         role,
		CreatedAt:    now,
		Disabled:     user.Disabled,
	}

	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return err
	}

	user.ID = model.ID.String()
	user.CreatedAt = model.CreatedAt
	user.Role = model.Role
	user.Disabled = model.Disabled
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
		Role:         model.Role,
		CreatedAt:    model.CreatedAt,
		Disabled:     model.Disabled,
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
		Role:         model.Role,
		CreatedAt:    model.CreatedAt,
		Disabled:     model.Disabled,
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

func (r *gormUserRepository) List(ctx context.Context, role string, disabled *bool, q string, limit, offset int) ([]*User, int64, error) {
	var models []userModel
	db := r.db.WithContext(ctx).Model(&userModel{})
	role = strings.TrimSpace(strings.ToLower(role))
	if role != "" {
		db = db.Where("role = ?", role)
	}
	if disabled != nil {
		db = db.Where("disabled = ?", *disabled)
	}
	q = strings.TrimSpace(strings.ToLower(q))
	if q != "" {
		like := "%" + q + "%"
		db = db.Where("LOWER(email) LIKE ? OR LOWER(name) LIKE ?", like, like)
	}
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	var total int64
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := db.Limit(limit).Offset(offset).Order("created_at DESC").Find(&models).Error; err != nil {
		return nil, 0, err
	}

	users := make([]*User, 0, len(models))
	for _, m := range models {
		users = append(users, &User{
			ID:           m.ID.String(),
			Name:         m.Name,
			Email:        m.Email,
			Phone:        m.Phone,
			PasswordHash: m.PasswordHash,
			Role:         m.Role,
			CreatedAt:    m.CreatedAt,
			Disabled:     m.Disabled,
		})
	}
	return users, total, nil
}

func (r *gormUserRepository) UpdateRoleAndStatus(ctx context.Context, id string, role *string, disabled *bool) (*User, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, gorm.ErrRecordNotFound
	}
	updates := map[string]any{}
	if role != nil {
		updates["role"] = strings.TrimSpace(strings.ToLower(*role))
	}
	if disabled != nil {
		updates["disabled"] = *disabled
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
