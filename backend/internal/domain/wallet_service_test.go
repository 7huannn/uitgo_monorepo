package domain_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"uitgo/backend/internal/domain"
)

type fakeWalletRepo struct {
	summaries    map[string]*domain.WalletSummary
	transactions map[string][]*domain.WalletTransaction
}

func newFakeWalletRepo() *fakeWalletRepo {
	return &fakeWalletRepo{
		summaries:    make(map[string]*domain.WalletSummary),
		transactions: make(map[string][]*domain.WalletTransaction),
	}
}

func (f *fakeWalletRepo) Get(ctx context.Context, userID string) (*domain.WalletSummary, error) {
	if summary, ok := f.summaries[userID]; ok {
		return &domain.WalletSummary{
			UserID:       summary.UserID,
			Balance:      summary.Balance,
			RewardPoints: summary.RewardPoints,
			UpdatedAt:    summary.UpdatedAt,
		}, nil
	}
	summary := &domain.WalletSummary{
		UserID:       userID,
		Balance:      0,
		RewardPoints: 0,
		UpdatedAt:    time.Now().UTC(),
	}
	f.summaries[userID] = summary
	return summary, nil
}

func (f *fakeWalletRepo) ListTransactions(ctx context.Context, userID string, limit, offset int) ([]*domain.WalletTransaction, int64, error) {
	rows := f.transactions[userID]
	total := int64(len(rows))
	if offset > len(rows) {
		offset = len(rows)
	}
	end := offset + limit
	if end > len(rows) {
		end = len(rows)
	}
	slice := rows[offset:end]
	items := make([]*domain.WalletTransaction, 0, len(slice))
	for _, row := range slice {
		items = append(items, &domain.WalletTransaction{
			ID:        row.ID,
			UserID:    row.UserID,
			Amount:    row.Amount,
			Type:      row.Type,
			CreatedAt: row.CreatedAt,
		})
	}
	return items, total, nil
}

func (f *fakeWalletRepo) ApplyTransaction(ctx context.Context, tx *domain.WalletTransaction) (*domain.WalletSummary, error) {
	summary, ok := f.summaries[tx.UserID]
	if !ok {
		summary = &domain.WalletSummary{
			UserID:       tx.UserID,
			Balance:      0,
			RewardPoints: 0,
			UpdatedAt:    time.Now().UTC(),
		}
		f.summaries[tx.UserID] = summary
	}
	switch tx.Type {
	case domain.WalletTransactionTypeTopUp:
		summary.Balance += tx.Amount
	case domain.WalletTransactionTypeDeduction:
		if summary.Balance < tx.Amount {
			return nil, domain.ErrWalletInsufficientFunds
		}
		summary.Balance -= tx.Amount
	case domain.WalletTransactionTypeReward:
		summary.RewardPoints += tx.Amount
	default:
		return nil, domain.ErrWalletInvalidAmount
	}
	summary.UpdatedAt = time.Now().UTC()
	tx.ID = time.Now().Format(time.RFC3339Nano)
	tx.CreatedAt = summary.UpdatedAt
	f.transactions[tx.UserID] = append([]*domain.WalletTransaction{tx}, f.transactions[tx.UserID]...)
	return summary, nil
}

var _ domain.WalletRepository = (*fakeWalletRepo)(nil)

func TestWalletServiceTopUpValidation(t *testing.T) {
	repo := newFakeWalletRepo()
	service := domain.NewWalletService(repo, domain.WithWalletConfig(domain.WalletServiceConfig{
		MinTopUpAmount: 20000,
		MaxTopUpAmount: 100000,
	}))
	ctx := context.Background()

	_, err := service.TopUp(ctx, "user-1", 10000)
	require.ErrorIs(t, err, domain.ErrWalletInvalidAmount)

	summary, err := service.TopUp(ctx, "user-1", 50000)
	require.NoError(t, err)
	require.Equal(t, int64(50000), summary.Balance)
}

func TestWalletServiceTripLifecycle(t *testing.T) {
	repo := newFakeWalletRepo()
	service := domain.NewWalletService(repo)
	ctx := context.Background()

	_, err := service.EnsureBalanceForTrip(ctx, "rider-1", "uit-bike")
	require.ErrorIs(t, err, domain.ErrWalletInsufficientFunds)

	_, err = service.TopUp(ctx, "rider-1", 60000)
	require.NoError(t, err)

	fare, err := service.EnsureBalanceForTrip(ctx, "rider-1", "uit-bike")
	require.NoError(t, err)
	require.Greater(t, fare, int64(0))

	afterDeduct, deducted, err := service.DeductTripFare(ctx, "rider-1", "uit-bike")
	require.NoError(t, err)
	require.Equal(t, deducted, fare)
	require.Equal(t, int64(60000)-fare, afterDeduct.Balance)

	rewarded, points, err := service.RewardTripCompletion(ctx, "rider-1")
	require.NoError(t, err)
	require.GreaterOrEqual(t, points, int64(0))
	require.Equal(t, rewarded.RewardPoints, points)
}

func TestWalletServiceTransactions(t *testing.T) {
	repo := newFakeWalletRepo()
	service := domain.NewWalletService(repo)
	ctx := context.Background()

	for i := 0; i < 5; i++ {
		amount := int64(10000 + i*1000)
		_, err := service.TopUp(ctx, "user-2", amount)
		require.NoError(t, err)
	}

	items, total, err := service.Transactions(ctx, "user-2", 3, 0)
	require.NoError(t, err)
	require.Equal(t, int64(5), total)
	require.Len(t, items, 3)
	require.Equal(t, domain.WalletTransactionTypeTopUp, items[0].Type)
	require.Greater(t, items[0].Amount, items[2].Amount)
}
