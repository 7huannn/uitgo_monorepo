package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// WalletHandler exposes wallet API endpoints.
type WalletHandler struct {
	service *domain.WalletService
}

// RegisterWalletRoutes maps wallet endpoints under /v1.
func RegisterWalletRoutes(router gin.IRouter, service *domain.WalletService) {
	if service == nil {
		return
	}
	handler := &WalletHandler{service: service}
	v1 := router.Group("/v1")
	{
		v1.GET("/wallet", handler.summary)
		v1.GET("/wallet/transactions", handler.transactions)
		v1.POST("/wallet/topup", handler.topUp)
	}
}

func (h *WalletHandler) summary(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}
	summary, err := h.service.Summary(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load wallet"})
		return
	}
	c.JSON(http.StatusOK, walletResponse{
		Balance:      summary.Balance,
		RewardPoints: summary.RewardPoints,
		UpdatedAt:    summary.UpdatedAt.UTC().Format(time.RFC3339),
	})
}

func (h *WalletHandler) transactions(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}
	limit := queryInt(c, "limit", 20, 100)
	offset := queryInt(c, "offset", 0, 1000)

	items, total, err := h.service.Transactions(c.Request.Context(), userID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list transactions"})
		return
	}

	resp := walletTransactionListResponse{
		Items:  make([]walletTransactionResponse, 0, len(items)),
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}
	for _, item := range items {
		resp.Items = append(resp.Items, walletTransactionResponse{
			ID:        item.ID,
			Type:      string(item.Type),
			Amount:    item.Amount,
			CreatedAt: item.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, resp)
}

type topUpRequest struct {
	Amount int64 `json:"amount"`
}

func (h *WalletHandler) topUp(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}
	var req topUpRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "amount is required"})
		return
	}
	if req.Amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be positive"})
		return
	}
	summary, err := h.service.TopUp(c.Request.Context(), userID, req.Amount)
	if err != nil {
		status := http.StatusInternalServerError
		if err == domain.ErrWalletInvalidAmount {
			status = http.StatusBadRequest
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, walletResponse{
		Balance:      summary.Balance,
		RewardPoints: summary.RewardPoints,
		UpdatedAt:    summary.UpdatedAt.UTC().Format(time.RFC3339),
	})
}

type walletTransactionListResponse struct {
	Items  []walletTransactionResponse `json:"items"`
	Total  int64                       `json:"total"`
	Limit  int                         `json:"limit"`
	Offset int                         `json:"offset"`
}

type walletTransactionResponse struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	Amount    int64  `json:"amount"`
	CreatedAt string `json:"createdAt"`
}

type walletResponse struct {
	Balance      int64  `json:"balance"`
	RewardPoints int64  `json:"rewardPoints"`
	UpdatedAt    string `json:"updatedAt"`
}
