package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"

	"uitgo/backend/internal/domain"
)

func TestWalletRoutes(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newTestWalletRepo()
	service := domain.NewWalletService(repo, domain.WithWalletConfig(domain.WalletServiceConfig{
		MinTopUpAmount: 10000,
		MaxTopUpAmount: 2000000,
	}))
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("userID", "wallet-user")
		c.Next()
	})
	RegisterWalletRoutes(router, service)

	// Initial summary should auto-provision wallet.
	getSummary := func() walletResponse {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/v1/wallet", nil)
		router.ServeHTTP(rec, req)
		require.Equal(t, http.StatusOK, rec.Code)
		var resp walletResponse
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
		return resp
	}

	summary := getSummary()
	require.Equal(t, int64(0), summary.Balance)

	// Top up increases balance immediately.
	payload := []byte(`{"amount":120000}`)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/wallet/topup", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusCreated, rec.Code)

	summary = getSummary()
	require.Equal(t, int64(120000), summary.Balance)

	// Transactions endpoint returns the top-up record.
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/v1/wallet/transactions?limit=10", nil)
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusOK, rec.Code)
	var list walletTransactionListResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &list))
	require.Len(t, list.Items, 1)
	require.Equal(t, "topup", list.Items[0].Type)
	require.Equal(t, int64(120000), list.Items[0].Amount)
}

// test wallet repo mimics persistence for handler tests.
type testWalletRepo struct {
	state map[string]*domain.WalletSummary
	logs  map[string][]*domain.WalletTransaction
}

func newTestWalletRepo() *testWalletRepo {
	return &testWalletRepo{
		state: make(map[string]*domain.WalletSummary),
		logs:  make(map[string][]*domain.WalletTransaction),
	}
}

func (r *testWalletRepo) Get(_ context.Context, userID string) (*domain.WalletSummary, error) {
	if summary, ok := r.state[userID]; ok {
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
	r.state[userID] = summary
	return summary, nil
}

func (r *testWalletRepo) ListTransactions(_ context.Context, userID string, limit, offset int) ([]*domain.WalletTransaction, int64, error) {
	items := r.logs[userID]
	total := int64(len(items))
	if offset > len(items) {
		offset = len(items)
	}
	end := offset + limit
	if end > len(items) {
		end = len(items)
	}
	slice := items[offset:end]
	copied := make([]*domain.WalletTransaction, 0, len(slice))
	for _, item := range slice {
		copied = append(copied, &domain.WalletTransaction{
			ID:        item.ID,
			UserID:    item.UserID,
			Amount:    item.Amount,
			Type:      item.Type,
			CreatedAt: item.CreatedAt,
		})
	}
	return copied, total, nil
}

func (r *testWalletRepo) ApplyTransaction(_ context.Context, tx *domain.WalletTransaction) (*domain.WalletSummary, error) {
	summary, ok := r.state[tx.UserID]
	if !ok {
		summary = &domain.WalletSummary{
			UserID:       tx.UserID,
			Balance:      0,
			RewardPoints: 0,
			UpdatedAt:    time.Now().UTC(),
		}
		r.state[tx.UserID] = summary
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
	r.logs[tx.UserID] = append([]*domain.WalletTransaction{tx}, r.logs[tx.UserID]...)
	return &domain.WalletSummary{
		UserID:       summary.UserID,
		Balance:      summary.Balance,
		RewardPoints: summary.RewardPoints,
		UpdatedAt:    summary.UpdatedAt,
	}, nil
}

var _ domain.WalletRepository = (*testWalletRepo)(nil)
