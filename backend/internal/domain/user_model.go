package domain

import "time"

// User represents an authenticated account.
type User struct {
	ID           string
	Name         string
	Email        string
	Phone        string
	PasswordHash string
	CreatedAt    time.Time
}
