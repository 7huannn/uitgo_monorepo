package middleware

import (
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type limiterState struct {
	limiter *rate.Limiter
	lastHit time.Time
}

// TokenBucketRateLimiter enforces a maximum number of requests from the same client.
type TokenBucketRateLimiter struct {
	mu        sync.Mutex
	limiters  map[string]*limiterState
	limit     rate.Limit
	burst     int
	ttl       time.Duration
	enabled   bool
	clock     func() time.Time
	namespace string
}

// NewTokenBucketRateLimiter creates a limiter that allows <requests> per <window>.
func NewTokenBucketRateLimiter(requests int, window time.Duration) *TokenBucketRateLimiter {
	if requests <= 0 {
		requests = 10
	}
	if window <= 0 {
		window = time.Minute
	}
	interval := window / time.Duration(requests)
	if interval <= 0 {
		interval = time.Second
	}
	return &TokenBucketRateLimiter{
		limiters: make(map[string]*limiterState),
		limit:    rate.Every(interval),
		burst:    requests,
		ttl:      window * 2,
		enabled:  true,
		clock:    time.Now,
	}
}

// Middleware returns a gin handler enforcing the limiter.
func (l *TokenBucketRateLimiter) Middleware(bucket string) gin.HandlerFunc {
	if l == nil || !l.enabled {
		return func(c *gin.Context) {
			c.Next()
		}
	}
	bucket = strings.TrimSpace(bucket)
	return func(c *gin.Context) {
		key := c.ClientIP()
		if key == "" {
			key = "unknown"
		}
		if bucket != "" {
			key = bucket + ":" + key
		}
		limiter := l.getLimiter(key)
		if !limiter.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "rate limit exceeded"})
			return
		}
		c.Next()
	}
}

func (l *TokenBucketRateLimiter) getLimiter(key string) *rate.Limiter {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.clock()
	if state, ok := l.limiters[key]; ok {
		state.lastHit = now
		return state.limiter
	}

	limiter := rate.NewLimiter(l.limit, l.burst)
	l.limiters[key] = &limiterState{
		limiter: limiter,
		lastHit: now,
	}
	for k, v := range l.limiters {
		if now.Sub(v.lastHit) > l.ttl {
			delete(l.limiters, k)
		}
	}
	return limiter
}
