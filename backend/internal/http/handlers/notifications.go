package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// NotificationHandler exposes notification endpoints.
type NotificationHandler struct {
	repo domain.NotificationRepository
}

// RegisterNotificationRoutes wires notification endpoints.
func RegisterNotificationRoutes(router gin.IRoutes, repo domain.NotificationRepository) {
	handler := &NotificationHandler{repo: repo}
	router.GET("/notifications", handler.list)
	router.PATCH("/notifications/:id/read", handler.markAsRead)
}

type notificationResponse struct {
	ID        string  `json:"id"`
	Title     string  `json:"title"`
	Body      string  `json:"body"`
	Type      string  `json:"type"`
	TripID    *string `json:"tripId,omitempty"`
	CreatedAt string  `json:"createdAt"`
	ReadAt    *string `json:"readAt,omitempty"`
}

type notificationListResponse struct {
	Items  []notificationResponse `json:"items"`
	Total  int64                  `json:"total"`
	Limit  int                    `json:"limit"`
	Offset int                    `json:"offset"`
}

func (h *NotificationHandler) list(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	limit := queryInt(c, "limit", 20, 100)
	offset := queryInt(c, "offset", 0, 1000)
	unreadOnly := strings.EqualFold(c.Query("unreadOnly"), "true")

	items, total, err := h.repo.List(c.Request.Context(), userID, unreadOnly, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load notifications"})
		return
	}

	resp := notificationListResponse{
		Items:  make([]notificationResponse, 0, len(items)),
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}
	for _, item := range items {
		resp.Items = append(resp.Items, toNotificationResponse(item))
	}
	c.JSON(http.StatusOK, resp)
}

func (h *NotificationHandler) markAsRead(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "notification id required"})
		return
	}

	if err := h.repo.MarkAsRead(c.Request.Context(), id, userID); err != nil {
		if err == domain.ErrNotificationNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "notification not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update notification"})
		return
	}

	c.Status(http.StatusNoContent)
}

func toNotificationResponse(n *domain.Notification) notificationResponse {
	resp := notificationResponse{
		ID:        n.ID,
		Title:     n.Title,
		Body:      n.Body,
		Type:      n.Type,
		TripID:    n.TripID,
		CreatedAt: n.CreatedAt.UTC().Format(time.RFC3339),
	}
	if n.ReadAt != nil {
		t := n.ReadAt.UTC().Format(time.RFC3339)
		resp.ReadAt = &t
	}
	return resp
}
