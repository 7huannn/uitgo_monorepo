package domain

import (
	"context"
	"time"
)

// WalletTransactionType enumerates the supported wallet transaction kinds.
type WalletTransactionType string

const (
	WalletTransactionTypeTopUp     WalletTransactionType = "topup"
	WalletTransactionTypeReward    WalletTransactionType = "reward"
	WalletTransactionTypeDeduction WalletTransactionType = "deduction"
)

// WalletSummary represents rider credits and points.
type WalletSummary struct {
	UserID       string    `json:"-"`
	Balance      int64     `json:"balance"`
	RewardPoints int64     `json:"rewardPoints"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

// WalletTransaction captures a statement line for the rider wallet.
type WalletTransaction struct {
	ID        string                `json:"id"`
	UserID    string                `json:"userId"`
	Amount    int64                 `json:"amount"`
	Type      WalletTransactionType `json:"type"`
	CreatedAt time.Time             `json:"createdAt"`
}

// WalletRepository coordinates wallet persistence.
type WalletRepository interface {
	Get(ctx context.Context, userID string) (*WalletSummary, error)
	ListTransactions(ctx context.Context, userID string, limit, offset int) ([]*WalletTransaction, int64, error)
	ApplyTransaction(ctx context.Context, tx *WalletTransaction) (*WalletSummary, error)
}

// WalletOperations exposes the subset of wallet behaviours used by other services.
type WalletOperations interface {
	EnsureBalanceForTrip(ctx context.Context, userID, serviceID string) (int64, error)
	DeductTripFare(ctx context.Context, userID, serviceID string) (*WalletSummary, int64, error)
	RewardTripCompletion(ctx context.Context, userID string) (*WalletSummary, int64, error)
}
