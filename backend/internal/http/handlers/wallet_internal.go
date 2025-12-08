package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// RegisterWalletInternalRoutes exposes wallet operations for internal services.
func RegisterWalletInternalRoutes(router gin.IRoutes, service *domain.WalletService) {
	if router == nil || service == nil {
		return
	}
	handler := &walletInternalHandler{service: service}
	router.POST("/wallet/transactions", handler.applyTransaction)
}

type walletInternalHandler struct {
	service *domain.WalletService
}

type walletTransactionRequest struct {
	UserID    string `json:"userId" binding:"required"`
	Amount    int64  `json:"amount" binding:"required"`
	Type      string `json:"type" binding:"required"`
	CreatedAt string `json:"createdAt"`
}

func (h *walletInternalHandler) applyTransaction(c *gin.Context) {
	var req walletTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	txType := domain.WalletTransactionType(strings.ToLower(strings.TrimSpace(req.Type)))
	tx := &domain.WalletTransaction{
		UserID: req.UserID,
		Amount: req.Amount,
		Type:   txType,
	}
	if req.CreatedAt != "" {
		if ts, err := time.Parse(time.RFC3339, req.CreatedAt); err == nil {
			tx.CreatedAt = ts
		}
	}

	summary, err := h.service.ApplyTransaction(c.Request.Context(), tx)
	if err != nil {
		status := http.StatusBadRequest
		if err == domain.ErrWalletInsufficientFunds {
			status = http.StatusPaymentRequired
		} else if err != domain.ErrWalletInvalidAmount {
			status = http.StatusInternalServerError
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
