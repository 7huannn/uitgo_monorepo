package handlers

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"uitgo/backend/internal/domain"
)

// AdminHandler exposes admin-only endpoints.
type AdminHandler struct {
	users  domain.UserRepository
	promos domain.PromotionRepository
}

func RegisterAdminRoutes(router gin.IRoutes, users domain.UserRepository, promos domain.PromotionRepository) {
	handler := &AdminHandler{users: users, promos: promos}
	router.GET("/users", handler.listUsers)
	router.PATCH("/users/:id", handler.updateUser)
	router.GET("/promotions", handler.listPromotions)
	router.POST("/promotions", handler.createPromotion)
	router.DELETE("/promotions/:id", handler.deletePromotion)
}

func (h *AdminHandler) listUsers(c *gin.Context) {
	role := strings.TrimSpace(strings.ToLower(c.Query("role")))
	q := strings.TrimSpace(c.Query("q"))
	limit := queryInt(c, "limit", 50, 200)
	offset := queryInt(c, "offset", 0, 5000)
	disabledParam := strings.TrimSpace(c.Query("disabled"))
	var disabled *bool
	if disabledParam != "" && disabledParam != "all" {
		switch strings.ToLower(disabledParam) {
		case "true", "1", "yes":
			val := true
			disabled = &val
		case "false", "0", "no":
			val := false
			disabled = &val
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid disabled value"})
			return
		}
	}

	users, total, err := h.users.List(c.Request.Context(), role, disabled, q, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list users"})
		return
	}

	resp := make([]userResponse, 0, len(users))
	for _, u := range users {
		resp = append(resp, toUserResponse(u))
	}

	c.JSON(http.StatusOK, gin.H{
		"items":  resp,
		"total":  total,
		"limit":  limit,
		"offset": offset,
	})
}

type updateUserRequest struct {
	Role     *string `json:"role"`
	Disabled *bool   `json:"disabled"`
}

func (h *AdminHandler) updateUser(c *gin.Context) {
	userID := c.Param("id")
	if strings.TrimSpace(userID) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user id required"})
		return
	}
	var req updateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Role == nil && req.Disabled == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "nothing to update"})
		return
	}
	if req.Role != nil {
		role := strings.TrimSpace(strings.ToLower(*req.Role))
		switch role {
		case "rider", "driver", "admin":
			req.Role = &role
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid role"})
			return
		}
	}

	user, err := h.users.UpdateRoleAndStatus(c.Request.Context(), userID, req.Role, req.Disabled)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user"})
		return
	}

	c.JSON(http.StatusOK, toUserResponse(user))
}

type promotionRequest struct {
	Title         string  `json:"title" binding:"required"`
	Description   string  `json:"description" binding:"required"`
	Code          string  `json:"code" binding:"required"`
	ImageURL      *string `json:"imageUrl"`
	GradientStart string  `json:"gradientStart" binding:"required"`
	GradientEnd   string  `json:"gradientEnd" binding:"required"`
	ExpiresAt     *string `json:"expiresAt"`
	Priority      int     `json:"priority"`
}

func (h *AdminHandler) listPromotions(c *gin.Context) {
	if h.promos == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "promotions unavailable"})
		return
	}
	items, err := h.promos.ListAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list promotions"})
		return
	}
	resp := make([]promotionResponse, 0, len(items))
	for _, p := range items {
		resp = append(resp, toPromotionResponse(p))
	}
	c.JSON(http.StatusOK, resp)
}

func (h *AdminHandler) createPromotion(c *gin.Context) {
	if h.promos == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "promotions unavailable"})
		return
	}
	var req promotionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var expires *time.Time
	if req.ExpiresAt != nil && strings.TrimSpace(*req.ExpiresAt) != "" {
		if t, err := time.Parse(time.RFC3339, strings.TrimSpace(*req.ExpiresAt)); err == nil {
			expires = &t
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "expiresAt must be RFC3339"})
			return
		}
	}
	promo := &domain.Promotion{
		Title:         strings.TrimSpace(req.Title),
		Description:   strings.TrimSpace(req.Description),
		Code:          strings.TrimSpace(req.Code),
		ImageURL:      req.ImageURL,
		GradientStart: strings.TrimSpace(req.GradientStart),
		GradientEnd:   strings.TrimSpace(req.GradientEnd),
		ExpiresAt:     expires,
		Priority:      req.Priority,
	}
	created, err := h.promos.Create(c.Request.Context(), promo)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create promotion"})
		return
	}
	c.JSON(http.StatusCreated, toPromotionResponse(created))
}

func (h *AdminHandler) deletePromotion(c *gin.Context) {
	if h.promos == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "promotions unavailable"})
		return
	}
	id := c.Param("id")
	if strings.TrimSpace(id) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "promotion id required"})
		return
	}
	if err := h.promos.Deactivate(c.Request.Context(), id); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "promotion not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete promotion"})
		return
	}
	c.Status(http.StatusNoContent)
}
