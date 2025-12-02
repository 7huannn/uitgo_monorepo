package handlers

import (
	"strconv"

	"github.com/gin-gonic/gin"
)

func queryInt(c *gin.Context, key string, fallback, max int) int {
	return sanitizeInt(c.Query(key), fallback, max)
}

func sanitizeInt(value string, fallback, max int) int {
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 0 {
		return fallback
	}
	if max > 0 && parsed > max {
		return max
	}
	return parsed
}
