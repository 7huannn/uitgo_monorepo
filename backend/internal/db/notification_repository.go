package db

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"uitgo/backend/internal/domain"
)

type notificationRepository struct {
	db *gorm.DB
}

// NewNotificationRepository creates a notification repository backed by GORM.
func NewNotificationRepository(db *gorm.DB) domain.NotificationRepository {
	return &notificationRepository{db: db}
}

type notificationModel struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID    string    `gorm:"index"`
	Title     string
	Body      string
	Type      string
	TripID    *uuid.UUID
	CreatedAt time.Time `gorm:"autoCreateTime"`
	ReadAt    *time.Time
}

func (notificationModel) TableName() string {
	return "notifications"
}

func (r *notificationRepository) Create(ctx context.Context, notification *domain.Notification) error {
	model, err := toNotificationModel(notification)
	if err != nil {
		return err
	}
	if err := r.db.WithContext(ctx).Create(model).Error; err != nil {
		return err
	}
	notification.ID = model.ID.String()
	notification.CreatedAt = model.CreatedAt
	return nil
}

func (r *notificationRepository) CreateMany(ctx context.Context, notifications []*domain.Notification) error {
	if len(notifications) == 0 {
		return nil
	}

	models := make([]*notificationModel, 0, len(notifications))
	for _, n := range notifications {
		model, err := toNotificationModel(n)
		if err != nil {
			return err
		}
		models = append(models, model)
	}

	if err := r.db.WithContext(ctx).Create(&models).Error; err != nil {
		return err
	}
	for idx, model := range models {
		notifications[idx].ID = model.ID.String()
		notifications[idx].CreatedAt = model.CreatedAt
	}
	return nil
}

func (r *notificationRepository) List(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]*domain.Notification, int64, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	query := r.db.WithContext(ctx).Model(&notificationModel{}).Where("user_id = ?", userID)
	if unreadOnly {
		query = query.Where("read_at IS NULL")
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var rows []notificationModel
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return nil, 0, err
	}

	items := make([]*domain.Notification, 0, len(rows))
	for _, row := range rows {
		items = append(items, toNotificationDomain(row))
	}
	return items, total, nil
}

func (r *notificationRepository) MarkAsRead(ctx context.Context, id, userID string) error {
	uid, err := uuid.Parse(id)
	if err != nil {
		return domain.ErrNotificationNotFound
	}

	now := time.Now().UTC()
	res := r.db.WithContext(ctx).Model(&notificationModel{}).
		Where("id = ? AND user_id = ?", uid, userID).
		Updates(map[string]any{"read_at": now})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return domain.ErrNotificationNotFound
	}
	return nil
}

func toNotificationModel(n *domain.Notification) (*notificationModel, error) {
	var id uuid.UUID
	if n.ID != "" {
		parsed, err := uuid.Parse(n.ID)
		if err != nil {
			return nil, err
		}
		id = parsed
	} else {
		id = uuid.New()
	}

	var tripID *uuid.UUID
	if n.TripID != nil && *n.TripID != "" {
		parsed, err := uuid.Parse(*n.TripID)
		if err == nil {
			tripID = &parsed
		}
	}

	return &notificationModel{
		ID:        id,
		UserID:    n.UserID,
		Title:     n.Title,
		Body:      n.Body,
		Type:      n.Type,
		TripID:    tripID,
		CreatedAt: n.CreatedAt,
		ReadAt:    n.ReadAt,
	}, nil
}

func toNotificationDomain(model notificationModel) *domain.Notification {
	var tripID *string
	if model.TripID != nil {
		id := model.TripID.String()
		tripID = &id
	}
	return &domain.Notification{
		ID:        model.ID.String(),
		UserID:    model.UserID,
		Title:     model.Title,
		Body:      model.Body,
		Type:      model.Type,
		TripID:    tripID,
		CreatedAt: model.CreatedAt,
		ReadAt:    model.ReadAt,
	}
}
