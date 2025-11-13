package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	userIDHeader        = "X-User-Id"
	roleHeader          = "X-Role"
	defaultUser         = "demo-user"
	internalTokenHeader = "X-Internal-Token"
)

// Auth attaches authentication info to the request context.
func Auth(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetHeader(userIDHeader)
		role := c.GetHeader(roleHeader)
		if jwtSecret != "" {
			if sub, r := parseBearer(c.GetHeader("Authorization"), jwtSecret); sub != "" {
				userID = sub
				if role == "" && r != "" {
					role = r
				}
			}
		}
		if userID == "" {
			userID = defaultUser
		}
		c.Set("userID", userID)
		c.Set("role", role)
		c.Set("userID", userID)
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

// InternalOnly restricts a route to internal callers by validating a static token.
func InternalOnly(secret string) gin.HandlerFunc {
	secret = strings.TrimSpace(secret)
	return func(c *gin.Context) {
		if secret == "" {
			c.Next()
			return
		}
		if token := c.GetHeader(internalTokenHeader); token != "" && token == secret {
			c.Next()
			return
		}
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "internal access only"})
	}
}

func parseBearer(header, secret string) (string, string) {
	header = strings.TrimSpace(header)
	const prefix = "Bearer "
	if header == "" || !strings.HasPrefix(header, prefix) {
		return "", ""
	}
	tokenString := strings.TrimSpace(header[len(prefix):])
	if tokenString == "" {
		return "", ""
	}
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrTokenSignatureInvalid
		}
		return []byte(secret), nil
	})
	if err != nil || token == nil || !token.Valid {
		return "", ""
	}
	if claims, ok := token.Claims.(jwt.MapClaims); ok {
		sub, _ := claims["sub"].(string)
		role, _ := claims["role"].(string)
		return sub, role
	}
	return "", ""
}
