package middleware

import (
	"crypto/subtle"
	"log"
	"net/http"
	"net/url"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	userIDHeader        = "X-User-Id"
	roleHeader          = "X-Role"
	internalTokenHeader = "X-Internal-Token"
)

// Auth attaches authentication info to the request context.
func Auth(jwtSecret, internalSecret string) gin.HandlerFunc {
	jwtSecret = strings.TrimSpace(jwtSecret)
	internalSecret = strings.TrimSpace(internalSecret)
	return func(c *gin.Context) {
		var userID string
		var role string

		if jwtSecret != "" {
			if sub, r := parseBearer(c.GetHeader("Authorization"), jwtSecret); sub != "" {
				userID = sub
				role = r
			}
			// SECURITY: Token via query params is deprecated and disabled
			// Query param tokens can leak via browser history, referrer headers, and server logs
			// Use Authorization header with Bearer token instead
			// Legacy code removed for security - see ADR for migration guide
		}

		if userID == "" && internalSecret != "" {
			headerSecret := strings.TrimSpace(c.GetHeader(internalTokenHeader))
			if headerSecret != "" && subtle.ConstantTimeCompare([]byte(headerSecret), []byte(internalSecret)) == 1 {
				userID = strings.TrimSpace(c.GetHeader(userIDHeader))
				role = strings.TrimSpace(c.GetHeader(roleHeader))
			}
		}

		if userID != "" {
			c.Set("userID", userID)
		}
		if role != "" {
			c.Set("role", role)
		}
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
// SECURITY: Do not allow wildcard (*) with credentials - this is a security vulnerability
func CORS(allowedOrigins []string) gin.HandlerFunc {
	var patterns []string
	for _, origin := range allowedOrigins {
		origin = strings.TrimSpace(origin)
		if origin == "" {
			continue
		}
		// SECURITY: Reject wildcard origin when credentials are enabled
		// Browsers will reject this anyway, but we should be explicit
		if origin == "*" {
			log.Printf("CORS warning: wildcard origin '*' is not secure with credentials, ignoring")
			continue
		}
		patterns = append(patterns, origin)
	}

	// SECURITY: If no valid origins configured, default to localhost only for development
	if len(patterns) == 0 {
		patterns = []string{"http://localhost", "http://127.0.0.1"}
		log.Printf("CORS warning: no origins configured, defaulting to localhost only")
	}

	return func(c *gin.Context) {
		originHeader := c.GetHeader("Origin")

		// If no origin header, it's likely a same-origin or non-browser request
		if originHeader == "" {
			c.Next()
			return
		}

		// Check if origin is allowed
		originAllowed := false
		for _, candidate := range patterns {
			if matchOrigin(candidate, originHeader) {
				originAllowed = true
				break
			}
		}

		if !originAllowed {
			if c.Request.Method == http.MethodOptions {
				c.AbortWithStatus(http.StatusForbidden)
				return
			}
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "origin not allowed"})
			return
		}

		// SECURITY: Echo back the specific origin, never use '*' with credentials
		c.Writer.Header().Set("Access-Control-Allow-Origin", originHeader)
		c.Writer.Header().Set("Vary", "Origin")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type,X-Request-Id")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET,POST,PATCH,PUT,DELETE,OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Max-Age", "86400")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

func matchOrigin(candidate, actual string) bool {
	candidate = strings.TrimSpace(candidate)
	actual = strings.TrimSpace(actual)
	if candidate == "" || actual == "" {
		return false
	}
	if candidate == "*" || candidate == actual {
		return true
	}
	if strings.HasSuffix(candidate, "*") {
		prefix := strings.TrimSuffix(candidate, "*")
		if prefix == "" {
			return true
		}
		return strings.HasPrefix(actual, prefix)
	}

	if strings.HasSuffix(candidate, ":*") {
		base := strings.TrimSuffix(candidate, ":*")
		if !strings.Contains(base, "://") {
			base = "http://" + base
		}
		cURL, err1 := url.Parse(base)
		aURL, err2 := url.Parse(actual)
		if err1 == nil && err2 == nil && cURL.Scheme == aURL.Scheme && cURL.Hostname() == aURL.Hostname() {
			return true
		}
	}

	cURL, err1 := url.Parse(candidate)
	aURL, err2 := url.Parse(actual)
	if err1 == nil && err2 == nil && cURL.Scheme == aURL.Scheme {
		if cURL.Hostname() == aURL.Hostname() {
			if cURL.Port() == "" || cURL.Port() == aURL.Port() {
				return true
			}
		}
	}
	return false
}

// InternalOnly restricts a route to internal callers by validating a static token.
// SECURITY: Always require a valid secret - do not allow bypass when empty
func InternalOnly(secret string) gin.HandlerFunc {
	secret = strings.TrimSpace(secret)
	return func(c *gin.Context) {
		// SECURITY: If no internal secret is configured, deny all internal requests
		// This prevents accidental exposure of internal endpoints
		if secret == "" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "internal endpoints not configured"})
			return
		}

		token := strings.TrimSpace(c.GetHeader(internalTokenHeader))
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "internal access only"})
			return
		}

		// Use constant-time comparison to prevent timing attacks
		if subtle.ConstantTimeCompare([]byte(token), []byte(secret)) != 1 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid internal token"})
			return
		}

		c.Next()
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
