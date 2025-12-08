package config

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// Config holds runtime configuration for the API server.
type Config struct {
	Port                    string
	DatabaseURL             string
	TripReplicaDatabaseURL  string
	AllowedOrigins          []string
	JWTSecret               string
	AccessTokenTTL          time.Duration
	RefreshTokenTTL         time.Duration
	RefreshTokenKey         string
	InternalAPIKey          string
	DriverServiceURL        string
	UserServiceURL          string
	TripServiceURL          string
	RedisAddr               string
	RedisPassword           string
	RedisDB                 int
	HomeCacheTTL            time.Duration
	MatchQueueBackend       string
	MatchQueueAddr          string
	MatchQueueDB            int
	MatchQueueName          string
	MatchQueueSQSURL        string
	AWSRegion               string
	FirebaseCredentialsFile string
	FirebaseCredentialsJSON string
	SentryDSN               string
	PrometheusEnabled       bool
	LogFormat               string
	Environment             string
	IsProduction            bool
	RoutingBaseURL          string
	AdminEmail              string
	AdminPassword           string
	AdminName               string
}

const devRefreshFallback = "***REMOVED***"

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbURL := os.Getenv("POSTGRES_DSN")
	replicaURL := strings.TrimSpace(os.Getenv("TRIP_DB_REPLICA_DSN"))
	jwtSecret := os.Getenv("JWT_SECRET")
	internalAPIKey := os.Getenv("INTERNAL_API_KEY")
	driverServiceURL := strings.TrimSpace(os.Getenv("DRIVER_SERVICE_URL"))
	userServiceURL := strings.TrimSpace(os.Getenv("USER_SERVICE_URL"))
	tripServiceURL := strings.TrimSpace(os.Getenv("TRIP_SERVICE_URL"))
	firebaseCredsFile := strings.TrimSpace(os.Getenv("FIREBASE_CREDENTIALS_FILE"))
	firebaseCredsJSON := strings.TrimSpace(os.Getenv("FIREBASE_CREDENTIALS_JSON"))
	redisAddr := strings.TrimSpace(os.Getenv("REDIS_ADDR"))
	redisPassword := os.Getenv("REDIS_PASSWORD")
	redisDB := parseIntEnv(os.Getenv("REDIS_DB"), 0)
	homeCacheTTL := parseDuration(os.Getenv("HOME_CACHE_TTL_SECONDS"), 300*time.Second, time.Second)

	matchQueueBackend := strings.TrimSpace(strings.ToLower(os.Getenv("QUEUE_BACKEND")))
	if matchQueueBackend == "" {
		matchQueueBackend = "redis"
	}
	matchQueueAddr := strings.TrimSpace(os.Getenv("MATCH_QUEUE_REDIS_ADDR"))
	if matchQueueAddr == "" {
		matchQueueAddr = redisAddr
	}
	matchQueueDB := parseIntEnv(os.Getenv("MATCH_QUEUE_REDIS_DB"), redisDB)
	matchQueueName := strings.TrimSpace(os.Getenv("MATCH_QUEUE_NAME"))
	if matchQueueName == "" {
		matchQueueName = "trip:requests"
	}
	matchQueueSQSURL := strings.TrimSpace(os.Getenv("MATCH_QUEUE_SQS_URL"))

	accessTTL := parseDuration(os.Getenv("ACCESS_TOKEN_TTL_MINUTES"), 15*time.Minute, time.Minute)
	refreshTTL := parseDuration(os.Getenv("REFRESH_TOKEN_TTL_DAYS"), 30*24*time.Hour, 24*time.Hour)

	sentryDSN := strings.TrimSpace(os.Getenv("SENTRY_DSN"))
	prometheusEnabled := parseBoolEnv(os.Getenv("PROMETHEUS_ENABLED"), true)
	logFormat := strings.TrimSpace(os.Getenv("LOG_FORMAT"))
	if logFormat == "" {
		logFormat = "json"
	}
	appEnv := strings.TrimSpace(os.Getenv("APP_ENV"))
	if appEnv == "" {
		appEnv = "development"
	}
	isProd := strings.EqualFold(appEnv, "prod") || strings.EqualFold(appEnv, "production")

	awsRegion := strings.TrimSpace(os.Getenv("AWS_REGION"))

	routingBaseURL := strings.TrimSpace(os.Getenv("ROUTING_BASE_URL"))
	if routingBaseURL == "" {
		routingBaseURL = "https://routing.openstreetmap.de/routed-bike"
	}

	adminEmail := strings.TrimSpace(os.Getenv("ADMIN_EMAIL"))
	adminPassword := strings.TrimSpace(os.Getenv("ADMIN_PASSWORD"))
	adminName := strings.TrimSpace(os.Getenv("ADMIN_NAME"))
	if adminName == "" {
		adminName = "UITGo Admin"
	}

	refreshKey := strings.TrimSpace(os.Getenv("REFRESH_TOKEN_ENCRYPTION_KEY"))
	switch {
	case refreshKey == "":
		if isProd {
			return nil, fmt.Errorf("refresh token encryption key missing in production")
		}
		log.Printf("warn: REFRESH_TOKEN_ENCRYPTION_KEY not set, using development fallback")
		refreshKey = devRefreshFallback
	case len(refreshKey) != 32:
		if isProd {
			return nil, fmt.Errorf("refresh token encryption key must be exactly 32 bytes, got %d", len(refreshKey))
		}
		log.Printf("warn: REFRESH_TOKEN_ENCRYPTION_KEY must be 32 bytes, got %d; falling back to development default", len(refreshKey))
		refreshKey = devRefreshFallback
	}

	rawOrigins := strings.TrimSpace(os.Getenv("CORS_ALLOWED_ORIGINS"))
	var origins []string
	defaultOrigins := []string{
		"http://localhost:*",
		"http://127.0.0.1:*",
		"https://localhost:*",
		"https://127.0.0.1:*",
	}
	if rawOrigins == "" {
		origins = append(origins, defaultOrigins...)
	} else {
		for _, value := range strings.Split(rawOrigins, ",") {
			if trimmed := strings.TrimSpace(value); trimmed != "" {
				origins = append(origins, trimmed)
			}
		}
		if len(origins) == 0 {
			origins = append(origins, defaultOrigins...)
		}
	}

	webOrigins := strings.TrimSpace(os.Getenv("WEB_APP_ORIGINS"))
	if webOrigins == "" {
		webOrigins = strings.TrimSpace(os.Getenv("WEB_APP_ORIGIN"))
	}
	if webOrigins != "" {
		for _, value := range strings.Split(webOrigins, ",") {
			origins = appendOriginIfMissing(origins, value)
		}
	}

	return &Config{
		Port:                    port,
		DatabaseURL:             dbURL,
		TripReplicaDatabaseURL:  replicaURL,
		AllowedOrigins:          origins,
		JWTSecret:               jwtSecret,
		AccessTokenTTL:          accessTTL,
		RefreshTokenTTL:         refreshTTL,
		RefreshTokenKey:         refreshKey,
		InternalAPIKey:          internalAPIKey,
		DriverServiceURL:        driverServiceURL,
		UserServiceURL:          userServiceURL,
		TripServiceURL:          tripServiceURL,
		RedisAddr:               redisAddr,
		RedisPassword:           redisPassword,
		RedisDB:                 redisDB,
		HomeCacheTTL:            homeCacheTTL,
		MatchQueueBackend:       matchQueueBackend,
		MatchQueueAddr:          matchQueueAddr,
		MatchQueueDB:            matchQueueDB,
		MatchQueueName:          matchQueueName,
		MatchQueueSQSURL:        matchQueueSQSURL,
		AWSRegion:               awsRegion,
		FirebaseCredentialsFile: firebaseCredsFile,
		FirebaseCredentialsJSON: firebaseCredsJSON,
		SentryDSN:               sentryDSN,
		PrometheusEnabled:       prometheusEnabled,
		LogFormat:               logFormat,
		Environment:             appEnv,
		IsProduction:            isProd,
		RoutingBaseURL:          routingBaseURL,
		AdminEmail:              adminEmail,
		AdminPassword:           adminPassword,
		AdminName:               adminName,
	}, nil
}

func parseDuration(value string, defaultValue time.Duration, unit time.Duration) time.Duration {
	value = strings.TrimSpace(value)
	if value == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return defaultValue
	}
	return time.Duration(parsed) * unit
}

func parseBoolEnv(value string, defaultValue bool) bool {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return defaultValue
	}
	switch value {
	case "1", "true", "yes", "y":
		return true
	case "0", "false", "no", "n":
		return false
	default:
		return defaultValue
	}
}

func parseIntEnv(value string, defaultValue int) int {
	value = strings.TrimSpace(value)
	if value == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return parsed
}

func appendOriginIfMissing(origins []string, candidate string) []string {
	candidate = strings.TrimSpace(candidate)
	if candidate == "" {
		return origins
	}
	for _, existing := range origins {
		if strings.EqualFold(existing, candidate) {
			return origins
		}
	}
	return append(origins, candidate)
}
