package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// HTTPMetrics instruments HTTP handlers with Prometheus collectors.
type HTTPMetrics struct {
	enabled bool
	request *prometheus.CounterVec
	latency *prometheus.HistogramVec
}

// NewHTTPMetrics configures HTTP metrics for the provided service.
func NewHTTPMetrics(service string, enabled bool) *HTTPMetrics {
	if !enabled {
		return &HTTPMetrics{enabled: false}
	}

	labels := prometheus.Labels{}
	if service != "" {
		labels["service"] = service
	}

	requests := prometheus.NewCounterVec(prometheus.CounterOpts{
		Namespace:   "uitgo",
		Subsystem:   "http",
		Name:        "requests_total",
		Help:        "Total number of HTTP requests handled.",
		ConstLabels: labels,
	}, []string{"method", "path", "status"})

	latency := prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Namespace:   "uitgo",
		Subsystem:   "http",
		Name:        "request_duration_seconds",
		Help:        "Histogram of request latencies.",
		ConstLabels: labels,
		Buckets:     prometheus.DefBuckets,
	}, []string{"method", "path", "status"})

	prometheus.MustRegister(requests, latency)

	return &HTTPMetrics{
		enabled: true,
		request: requests,
		latency: latency,
	}
}

// Handler returns a middleware that records per-request metrics.
func (m *HTTPMetrics) Handler() gin.HandlerFunc {
	if m == nil || !m.enabled {
		return func(c *gin.Context) {
			c.Next()
		}
	}
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}
		status := strconv.Itoa(c.Writer.Status())
		labels := []string{c.Request.Method, path, status}

		m.request.WithLabelValues(labels...).Inc()
		m.latency.WithLabelValues(labels...).Observe(time.Since(start).Seconds())
	}
}

// Expose registers the /metrics endpoint if enabled.
func (m *HTTPMetrics) Expose(router gin.IRoutes) {
	if m == nil || !m.enabled {
		return
	}
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))
}
