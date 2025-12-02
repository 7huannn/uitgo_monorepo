package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// RegisterHealth wires the health check endpoint.
func RegisterHealth(router gin.IRoutes) {
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
}
