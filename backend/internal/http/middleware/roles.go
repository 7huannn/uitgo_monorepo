package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// RequireRoles ensures the authenticated user has one of the allowed roles.
func RequireRoles(allowed ...string) gin.HandlerFunc {
	allowedSet := make(map[string]struct{}, len(allowed))
	for _, role := range allowed {
		trimmed := strings.ToLower(strings.TrimSpace(role))
		if trimmed != "" {
			allowedSet[trimmed] = struct{}{}
		}
	}

	return func(c *gin.Context) {
		roleVal, _ := c.Get("role")
		role, _ := roleVal.(string)
		role = strings.ToLower(strings.TrimSpace(role))
		if role == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing role context"})
			return
		}
		if len(allowedSet) > 0 {
			if _, ok := allowedSet[role]; !ok {
				c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "admin role required"})
				return
			}
		}
		c.Next()
	}
}
