package domain

import (
	"context"
	"time"
)

// Notification represents a user-facing alert.
type Notification struct {
	ID        string     `json:"id"`
	UserID    string     `json:"userId"`
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	Type      string     `json:"type"`
	TripID    *string    `json:"tripId,omitempty"`
	CreatedAt time.Time  `json:"createdAt"`
	ReadAt    *time.Time `json:"readAt,omitempty"`
}

// NotificationRepository persists and queries notifications.
type NotificationRepository interface {
	Create(ctx context.Context, notification *Notification) error
	CreateMany(ctx context.Context, notifications []*Notification) error
	List(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]*Notification, int64, error)
	MarkAsRead(ctx context.Context, id, userID string) error
}

// TripEventNotifier dispatches push notifications for trip lifecycle events.
type TripEventNotifier interface {
	NotifyDriverTripAssigned(ctx context.Context, driver *Driver, trip *Trip) error
	NotifyRiderStatusChange(ctx context.Context, trip *Trip, status TripStatus) error
}
