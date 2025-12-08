package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"uitgo/backend/internal/domain"
)

// WalletClient proxies wallet operations to the user-service.
type WalletClient struct {
	baseURL string
	apiKey  string
	client  *http.Client
	cfg     domain.WalletServiceConfig
}

// NewWalletClient constructs a WalletClient for the provided base URL.
func NewWalletClient(baseURL, apiKey string) *WalletClient {
	trimmed := strings.TrimSpace(baseURL)
	trimmed = strings.TrimSuffix(trimmed, "/")
	return &WalletClient{
		baseURL: trimmed,
		apiKey:  apiKey,
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		cfg: domain.DefaultWalletConfig(),
	}
}

var _ domain.WalletOperations = (*WalletClient)(nil)

func (c *WalletClient) EnsureBalanceForTrip(ctx context.Context, userID, serviceID string) (int64, error) {
	summary, err := c.fetchSummary(ctx, userID)
	if err != nil {
		return 0, err
	}
	fare := c.fareForService(serviceID)
	if summary.Balance < fare {
		return fare, domain.ErrWalletInsufficientFunds
	}
	return fare, nil
}

func (c *WalletClient) DeductTripFare(ctx context.Context, userID, serviceID string) (*domain.WalletSummary, int64, error) {
	fare := c.fareForService(serviceID)
	summary, err := c.applyTransaction(ctx, userID, fare, domain.WalletTransactionTypeDeduction)
	return summary, fare, err
}

func (c *WalletClient) RewardTripCompletion(ctx context.Context, userID string) (*domain.WalletSummary, int64, error) {
	if c.cfg.RewardPointsPerTrip <= 0 {
		summary, err := c.fetchSummary(ctx, userID)
		return summary, 0, err
	}
	summary, err := c.applyTransaction(ctx, userID, c.cfg.RewardPointsPerTrip, domain.WalletTransactionTypeReward)
	return summary, c.cfg.RewardPointsPerTrip, err
}

func (c *WalletClient) fetchSummary(ctx context.Context, userID string) (*domain.WalletSummary, error) {
	if c == nil || c.baseURL == "" {
		return nil, errors.New("wallet service url not configured")
	}
	if strings.TrimSpace(userID) == "" {
		return nil, errors.New("user id required")
	}
	endpoint := fmt.Sprintf("%s/v1/wallet", c.baseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	c.attachHeaders(req, userID)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, c.decodeError(resp)
	}

	var payload walletResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}
	var updatedAt time.Time
	if payload.UpdatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payload.UpdatedAt); err == nil {
			updatedAt = parsed
		}
	}
	return &domain.WalletSummary{
		UserID:       userID,
		Balance:      payload.Balance,
		RewardPoints: payload.RewardPoints,
		UpdatedAt:    updatedAt,
	}, nil
}

func (c *WalletClient) applyTransaction(ctx context.Context, userID string, amount int64, txType domain.WalletTransactionType) (*domain.WalletSummary, error) {
	if c == nil || c.baseURL == "" {
		return nil, errors.New("wallet service url not configured")
	}
	if strings.TrimSpace(userID) == "" {
		return nil, errors.New("user id required")
	}
	if amount <= 0 {
		return nil, domain.ErrWalletInvalidAmount
	}

	payload := walletTransactionPayload{
		UserID: userID,
		Amount: amount,
		Type:   string(txType),
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("%s/internal/wallet/transactions", c.baseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	c.attachHeaders(req, userID)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, c.decodeError(resp)
	}

	var payloadResp walletResponse
	if err := json.NewDecoder(resp.Body).Decode(&payloadResp); err != nil {
		return nil, err
	}
	var updatedAt time.Time
	if payloadResp.UpdatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payloadResp.UpdatedAt); err == nil {
			updatedAt = parsed
		}
	}
	return &domain.WalletSummary{
		UserID:       userID,
		Balance:      payloadResp.Balance,
		RewardPoints: payloadResp.RewardPoints,
		UpdatedAt:    updatedAt,
	}, nil
}

func (c *WalletClient) attachHeaders(req *http.Request, userID string) {
	if req == nil {
		return
	}
	if c.apiKey != "" {
		req.Header.Set("X-Internal-Token", c.apiKey)
	}
	req.Header.Set("X-User-Id", userID)
}

func (c *WalletClient) decodeError(resp *http.Response) error {
	if resp == nil {
		return errors.New("wallet service error")
	}
	body, _ := io.ReadAll(resp.Body)
	message := strings.TrimSpace(string(body))
	if message == "" {
		message = resp.Status
	}
	switch {
	case strings.Contains(strings.ToLower(message), "insufficient"):
		return domain.ErrWalletInsufficientFunds
	case resp.StatusCode == http.StatusBadRequest:
		return domain.ErrWalletInvalidAmount
	default:
		return fmt.Errorf("wallet service error: %s", message)
	}
}

func (c *WalletClient) fareForService(serviceID string) int64 {
	if serviceID != "" {
		if fare, ok := c.cfg.ServiceFares[strings.ToLower(serviceID)]; ok && fare > 0 {
			return fare
		}
	}
	return c.cfg.DefaultTripFare
}

type walletTransactionPayload struct {
	UserID string `json:"userId"`
	Amount int64  `json:"amount"`
	Type   string `json:"type"`
}

type walletResponse struct {
	Balance      int64  `json:"balance"`
	RewardPoints int64  `json:"rewardPoints"`
	UpdatedAt    string `json:"updatedAt"`
}
