package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const (
	userIDHeader = "X-User-Id"
	roleHeader   = "X-Role"
	defaultUser  = "demo-user"
)

// Auth attaches mock authentication info to the request context.
func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetHeader(userIDHeader)
		if userID == "" {
			userID = defaultUser
		}
		c.Set("userID", userID)
		c.Set("role", c.GetHeader(roleHeader))
		c.Next()
	}
}

// RequestID adds a best-effort request ID for tracing.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-Id")
		if requestID == "" {
			requestID = uuid.NewString()
		}
		c.Set("requestID", requestID)
		c.Writer.Header().Set("X-Request-Id", requestID)
		c.Next()
	}
}

// CORS enables configurable CORS.
func CORS(allowedOrigins []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		originHeader := c.GetHeader("Origin")
		allowOrigin := "*"
		if len(allowedOrigins) > 0 {
			for _, candidate := range allowedOrigins {
				if candidate == "*" {
					allowOrigin = "*"
					break
				}
				if originHeader != "" && originHeader == candidate {
					allowOrigin = originHeader
					break
				}
			}
			// fallback to first configured origin if no match and wildcard not provided
			if allowOrigin != "*" && originHeader == "" {
				allowOrigin = allowedOrigins[0]
			}
		}
		c.Writer.Header().Set("Access-Control-Allow-Origin", allowOrigin)
		c.Writer.Header().Set("Access-Control-Allow-Headers", "*,Authorization,X-User-Id,X-Role")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET,POST,PATCH,OPTIONS")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
