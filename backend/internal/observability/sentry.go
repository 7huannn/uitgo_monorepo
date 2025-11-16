package observability

import (
	"log"
	"os"
	"strings"
	"time"

	"github.com/getsentry/sentry-go"
	sentrygin "github.com/getsentry/sentry-go/gin"
	"github.com/gin-gonic/gin"
)

// InitSentry configures Sentry with the provided DSN. The returned function should
// be deferred in main() to flush buffered events.
func InitSentry(dsn, service string) func() {
	dsn = strings.TrimSpace(dsn)
	if dsn == "" {
		return func() {}
	}

	env := strings.TrimSpace(os.Getenv("SENTRY_ENVIRONMENT"))
	if env == "" {
		env = "development"
	}

	err := sentry.Init(sentry.ClientOptions{
		Dsn:              dsn,
		Environment:      env,
		Release:          os.Getenv("GIT_SHA"),
		TracesSampleRate: 0.2,
	})
	if err != nil {
		log.Printf("warn: sentry init failed: %v", err)
		return func() {}
	}
	if service != "" {
		sentry.ConfigureScope(func(scope *sentry.Scope) {
			scope.SetTag("service", service)
		})
	}

	return func() {
		sentry.Flush(5 * time.Second)
	}
}

// GinMiddleware returns the sentry-gin middleware with panic reporting enabled.
func GinMiddleware() gin.HandlerFunc {
	if sentry.CurrentHub().Client() == nil {
		return func(c *gin.Context) { c.Next() }
	}
	return sentrygin.New(sentrygin.Options{
		Repanic: true,
	})
}
