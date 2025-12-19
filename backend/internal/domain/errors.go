package domain

import "errors"

// ErrTripNotFound indicates the requested trip does not exist.
var (
	ErrTripNotFound            = errors.New("trip not found")
	ErrInvalidStatus           = errors.New("invalid status")
	ErrNotificationNotFound    = errors.New("notification not found")
	ErrSavedPlaceNotFound      = errors.New("saved place not found")
	ErrDriverNotFound          = errors.New("driver not found")
	ErrDriverAlreadyExists     = errors.New("driver already exists")
	ErrVehicleAlreadyExists    = errors.New("vehicle already exists")
	ErrDriverOffline           = errors.New("driver offline")
	ErrNoDriversAvailable      = errors.New("no drivers available")
	ErrTripAssignmentNotFound  = errors.New("trip assignment not found")
	ErrAssignmentConflict      = errors.New("assignment conflict")
	ErrWalletInvalidAmount     = errors.New("invalid wallet amount")
	ErrWalletInsufficientFunds = errors.New("insufficient wallet balance")
)
