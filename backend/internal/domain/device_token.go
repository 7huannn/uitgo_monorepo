package domain

import (
	"context"
	"time"
)

// DeviceToken represents an FCM/Web push token tied to a user.
type DeviceToken struct {
	ID        string    `json:"id"`
	UserID    string    `json:"userId"`
	Platform  string    `json:"platform"`
	Token     string    `json:"token"`
	CreatedAt time.Time `json:"createdAt"`
}

// DeviceTokenRepository persists and queries device tokens.
type DeviceTokenRepository interface {
	Register(ctx context.Context, userID, platform, token string) (*DeviceToken, error)
	ListByUsers(ctx context.Context, userIDs []string) ([]*DeviceToken, error)
}
