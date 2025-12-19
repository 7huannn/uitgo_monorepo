package domain

import (
	"context"
	"errors"
	"strings"
)

// WalletService orchestrates wallet balance & transaction workflows.
type WalletService struct {
	repo WalletRepository
	cfg  WalletServiceConfig
}

// WalletServiceConfig tunes limits and reward logic.
type WalletServiceConfig struct {
	MinTopUpAmount      int64
	MaxTopUpAmount      int64
	DefaultTripFare     int64
	RewardPointsPerTrip int64
	ServiceFares        map[string]int64
}

// WalletServiceOption customises wallet behaviour.
type WalletServiceOption func(*WalletServiceConfig)

// WithWalletConfig replaces the default wallet configuration.
func WithWalletConfig(cfg WalletServiceConfig) WalletServiceOption {
	return func(current *WalletServiceConfig) {
		if cfg.MinTopUpAmount > 0 {
			current.MinTopUpAmount = cfg.MinTopUpAmount
		}
		if cfg.MaxTopUpAmount > 0 && cfg.MaxTopUpAmount >= cfg.MinTopUpAmount {
			current.MaxTopUpAmount = cfg.MaxTopUpAmount
		}
		if cfg.DefaultTripFare > 0 {
			current.DefaultTripFare = cfg.DefaultTripFare
		}
		if cfg.RewardPointsPerTrip >= 0 {
			current.RewardPointsPerTrip = cfg.RewardPointsPerTrip
		}
		if len(cfg.ServiceFares) > 0 {
			current.ServiceFares = make(map[string]int64, len(cfg.ServiceFares))
			for k, v := range cfg.ServiceFares {
				if v > 0 {
					current.ServiceFares[strings.ToLower(k)] = v
				}
			}
		}
	}
}

// NewWalletService wires a domain service for wallet operations.
func NewWalletService(repo WalletRepository, opts ...WalletServiceOption) *WalletService {
	cfg := DefaultWalletConfig()
	for _, opt := range opts {
		if opt != nil {
			opt(&cfg)
		}
	}
	return &WalletService{
		repo: repo,
		cfg:  cfg,
	}
}

// DefaultWalletConfig returns the baseline wallet configuration.
func DefaultWalletConfig() WalletServiceConfig {
	return WalletServiceConfig{
		MinTopUpAmount:      10000,
		MaxTopUpAmount:      5000000,
		// Demo env: disable fare checks so riders can always create trips without funding a wallet.
		DefaultTripFare:     0,
		RewardPointsPerTrip: 0,
		ServiceFares: map[string]int64{
			"uit-bike":  0,
			"uit-go":    0,
			"uit-car":   0,
			"uit-plus":  0,
			"uit-rider": 0,
		},
	}
}

// Summary returns or initialises the wallet for the user.
func (s *WalletService) Summary(ctx context.Context, userID string) (*WalletSummary, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	return s.repo.Get(ctx, userID)
}

// Transactions lists paginated wallet transactions.
func (s *WalletService) Transactions(ctx context.Context, userID string, limit, offset int) ([]*WalletTransaction, int64, error) {
	if userID == "" {
		return nil, 0, errors.New("user id required")
	}
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	return s.repo.ListTransactions(ctx, userID, limit, offset)
}

// TopUp credits the wallet balance instantly for mock flows.
func (s *WalletService) TopUp(ctx context.Context, userID string, amount int64) (*WalletSummary, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	if amount < s.cfg.MinTopUpAmount || amount > s.cfg.MaxTopUpAmount {
		return nil, ErrWalletInvalidAmount
	}
	return s.ApplyTransaction(ctx, &WalletTransaction{
		UserID: userID,
		Amount: amount,
		Type:   WalletTransactionTypeTopUp,
	})
}

// EnsureBalanceForTrip enforces riders keep sufficient funds before booking.
func (s *WalletService) EnsureBalanceForTrip(ctx context.Context, userID, serviceID string) (int64, error) {
	if userID == "" {
		return 0, errors.New("user id required")
	}
	fare := s.fareForService(serviceID)
	summary, err := s.repo.Get(ctx, userID)
	if err != nil {
		return 0, err
	}
	if summary.Balance < fare {
		return fare, ErrWalletInsufficientFunds
	}
	return fare, nil
}

// DeductTripFare debits the rider wallet after trip completion.
func (s *WalletService) DeductTripFare(ctx context.Context, userID, serviceID string) (*WalletSummary, int64, error) {
	if userID == "" {
		return nil, 0, errors.New("user id required")
	}
	fare := s.fareForService(serviceID)
	summary, err := s.ApplyTransaction(ctx, &WalletTransaction{
		UserID: userID,
		Amount: fare,
		Type:   WalletTransactionTypeDeduction,
	})
	return summary, fare, err
}

// RewardTripCompletion grants loyalty points/promotions after a trip.
func (s *WalletService) RewardTripCompletion(ctx context.Context, userID string) (*WalletSummary, int64, error) {
	if userID == "" {
		return nil, 0, errors.New("user id required")
	}
	if s.cfg.RewardPointsPerTrip <= 0 {
		summary, err := s.repo.Get(ctx, userID)
		return summary, 0, err
	}
	summary, err := s.ApplyTransaction(ctx, &WalletTransaction{
		UserID: userID,
		Amount: s.cfg.RewardPointsPerTrip,
		Type:   WalletTransactionTypeReward,
	})
	return summary, s.cfg.RewardPointsPerTrip, err
}

// ApplyTransaction applies a wallet transaction with validation.
func (s *WalletService) ApplyTransaction(ctx context.Context, tx *WalletTransaction) (*WalletSummary, error) {
	if tx == nil {
		return nil, errors.New("transaction required")
	}
	if tx.UserID == "" {
		return nil, errors.New("user id required")
	}
	if tx.Amount <= 0 {
		return nil, ErrWalletInvalidAmount
	}

	switch tx.Type {
	case WalletTransactionTypeTopUp:
		if tx.Amount < s.cfg.MinTopUpAmount || tx.Amount > s.cfg.MaxTopUpAmount {
			return nil, ErrWalletInvalidAmount
		}
	case WalletTransactionTypeDeduction, WalletTransactionTypeReward:
	default:
		return nil, ErrWalletInvalidAmount
	}

	return s.repo.ApplyTransaction(ctx, tx)
}

func (s *WalletService) fareForService(serviceID string) int64 {
	if serviceID != "" {
		if fare, ok := s.cfg.ServiceFares[strings.ToLower(serviceID)]; ok && fare > 0 {
			return fare
		}
	}
	return s.cfg.DefaultTripFare
}

var _ WalletOperations = (*WalletService)(nil)
