package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// HomeHandler exposes rider home related endpoints.
type HomeHandler struct {
	service *domain.HomeService
}

// RegisterHomeRoutes wires wallet/saved place/promotions/news routes.
func RegisterHomeRoutes(router gin.IRoutes, service *domain.HomeService) {
	handler := &HomeHandler{service: service}
	router.GET("/wallet", handler.wallet)
	router.GET("/saved_places", handler.savedPlaces)
	router.POST("/saved_places", handler.createSavedPlace)
	router.DELETE("/saved_places/:id", handler.deleteSavedPlace)
	router.GET("/promotions", handler.promotions)
	router.GET("/news", handler.news)
}

func (h *HomeHandler) wallet(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	summary, err := h.service.Wallet(c.Request.Context(), userID)
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

type savedPlaceResponse struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Address   string  `json:"address"`
	Latitude  float64 `json:"lat"`
	Longitude float64 `json:"lng"`
	CreatedAt string  `json:"createdAt"`
	UpdatedAt string  `json:"updatedAt"`
}

func (h *HomeHandler) savedPlaces(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	items, err := h.service.SavedPlaces(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load saved places"})
		return
	}

	resp := make([]savedPlaceResponse, 0, len(items))
	for _, item := range items {
		resp = append(resp, toSavedPlaceResponse(item))
	}
	c.JSON(http.StatusOK, resp)
}

type createSavedPlaceRequest struct {
	Name      string  `json:"name" binding:"required"`
	Address   string  `json:"address" binding:"required"`
	Latitude  float64 `json:"lat" binding:"required"`
	Longitude float64 `json:"lng" binding:"required"`
}

func (h *HomeHandler) createSavedPlace(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	var req createSavedPlaceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	place, err := h.service.CreateSavedPlace(c.Request.Context(), userID, &domain.SavedPlace{
		Name:      req.Name,
		Address:   req.Address,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save place"})
		return
	}

	c.JSON(http.StatusCreated, toSavedPlaceResponse(place))
}

func (h *HomeHandler) deleteSavedPlace(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "saved place id required"})
		return
	}

	if err := h.service.DeleteSavedPlace(c.Request.Context(), userID, id); err != nil {
		if err == domain.ErrSavedPlaceNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "saved place not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete saved place"})
		return
	}

	c.Status(http.StatusNoContent)
}

type promotionResponse struct {
	ID            string  `json:"id"`
	Title         string  `json:"title"`
	Description   string  `json:"description"`
	Code          string  `json:"code"`
	ImageURL      *string `json:"imageUrl,omitempty"`
	GradientStart string  `json:"gradientStart"`
	GradientEnd   string  `json:"gradientEnd"`
	ExpiresAt     *string `json:"expiresAt,omitempty"`
	Priority      int     `json:"priority"`
	IsActive      bool    `json:"isActive"`
}

func (h *HomeHandler) promotions(c *gin.Context) {
	items, err := h.service.Promotions(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load promotions"})
		return
	}

	resp := make([]promotionResponse, 0, len(items))
	for _, item := range items {
		resp = append(resp, toPromotionResponse(item))
	}
	c.JSON(http.StatusOK, resp)
}

type newsResponse struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Body        string `json:"body"`
	Category    string `json:"category"`
	Icon        string `json:"icon"`
	PublishedAt string `json:"publishedAt"`
}

func (h *HomeHandler) news(c *gin.Context) {
	limit := queryInt(c, "limit", 5, 50)
	items, err := h.service.News(c.Request.Context(), limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load news"})
		return
	}

	resp := make([]newsResponse, 0, len(items))
	for _, item := range items {
		resp = append(resp, newsResponse{
			ID:          item.ID,
			Title:       item.Title,
			Body:        item.Body,
			Category:    item.Category,
			Icon:        item.Icon,
			PublishedAt: item.PublishedAt.UTC().Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, resp)
}

func toSavedPlaceResponse(place *domain.SavedPlace) savedPlaceResponse {
	return savedPlaceResponse{
		ID:        place.ID,
		Name:      place.Name,
		Address:   place.Address,
		Latitude:  place.Latitude,
		Longitude: place.Longitude,
		CreatedAt: place.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt: place.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

func toPromotionResponse(p *domain.Promotion) promotionResponse {
	var expires *string
	if p.ExpiresAt != nil {
		formatted := p.ExpiresAt.UTC().Format(time.RFC3339)
		expires = &formatted
	}
	return promotionResponse{
		ID:            p.ID,
		Title:         p.Title,
		Description:   p.Description,
		Code:          p.Code,
		ImageURL:      p.ImageURL,
		GradientStart: p.GradientStart,
		GradientEnd:   p.GradientEnd,
		ExpiresAt:     expires,
		Priority:      p.Priority,
		IsActive:      p.IsActive,
	}
}
