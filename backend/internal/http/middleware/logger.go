package middleware

import (
	"encoding/json"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// JSONLogger returns a Gin logger that emits structured logs.
func JSONLogger(service string) gin.HandlerFunc {
	return gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {
		entry := map[string]any{
			"timestamp":  param.TimeStamp.UTC().Format(time.RFC3339Nano),
			"status":     param.StatusCode,
			"method":     param.Method,
			"path":       param.Path,
			"latency_ms": param.Latency.Milliseconds(),
			"ip":         param.ClientIP,
			"size":       param.BodySize,
		}
		if service != "" {
			entry["service"] = service
		}
		if param.ErrorMessage != "" {
			entry["error"] = strings.TrimSpace(param.ErrorMessage)
		}

		payload, err := json.Marshal(entry)
		if err != nil {
			return param.ErrorMessage
		}
		return string(payload) + "\n"
	})
}
