package middleware

import (
	"context"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/domain"
)

// AuditLogger records request metadata into the audit log repository.
func AuditLogger(repo domain.AuditLogRepository) gin.HandlerFunc {
	if repo == nil {
		return func(c *gin.Context) {
			c.Next()
		}
	}
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		status := c.Writer.Status()
		outcome := "success"
		errMsg := ""
		if status >= 400 {
			outcome = "failure"
		}
		if len(c.Errors) > 0 {
			outcome = "failure"
			errMsg = c.Errors.String()
		}

		entry := &domain.AuditLog{
			UserID:     c.GetString("userID"),
			Method:     c.Request.Method,
			Path:       c.FullPath(),
			StatusCode: status,
			IPAddress:  c.ClientIP(),
			UserAgent:  c.GetHeader("User-Agent"),
			RequestID:  c.GetString("requestID"),
			Outcome:    outcome,
			Error:      strings.TrimSpace(errMsg),
			Latency:    time.Since(start),
		}

		if entry.Path == "" {
			entry.Path = c.Request.URL.Path
		}

		go repo.Create(context.Background(), entry)
	}
}
