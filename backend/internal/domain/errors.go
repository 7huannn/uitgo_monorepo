package domain

import "errors"

// ErrTripNotFound indicates the requested trip does not exist.
var (
	ErrTripNotFound         = errors.New("trip not found")
	ErrInvalidStatus        = errors.New("invalid status")
	ErrNotificationNotFound = errors.New("notification not found")
)
