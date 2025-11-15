package config

import (
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds runtime configuration for the API server.
type Config struct {
	Port                    string
	DatabaseURL             string
	AllowedOrigins          []string
	JWTSecret               string
	InternalAPIKey          string
	DriverServiceURL        string
	TripServiceURL          string
	FirebaseCredentialsFile string
	FirebaseCredentialsJSON string
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbURL := os.Getenv("POSTGRES_DSN")
	jwtSecret := os.Getenv("JWT_SECRET")
	internalAPIKey := os.Getenv("INTERNAL_API_KEY")
	driverServiceURL := strings.TrimSpace(os.Getenv("DRIVER_SERVICE_URL"))
	tripServiceURL := strings.TrimSpace(os.Getenv("TRIP_SERVICE_URL"))
	firebaseCredsFile := strings.TrimSpace(os.Getenv("FIREBASE_CREDENTIALS_FILE"))
	firebaseCredsJSON := strings.TrimSpace(os.Getenv("FIREBASE_CREDENTIALS_JSON"))

	rawOrigins := strings.TrimSpace(os.Getenv("CORS_ALLOWED_ORIGINS"))
	var origins []string
	if rawOrigins == "" {
		origins = []string{"http://localhost:8080", "http://127.0.0.1:8080"}
	} else {
		for _, value := range strings.Split(rawOrigins, ",") {
			if trimmed := strings.TrimSpace(value); trimmed != "" {
				origins = append(origins, trimmed)
			}
		}
		if len(origins) == 0 {
			origins = []string{"http://localhost:8080", "http://127.0.0.1:8080"}
		}
	}

	return &Config{
		Port:                    port,
		DatabaseURL:             dbURL,
		AllowedOrigins:          origins,
		JWTSecret:               jwtSecret,
		InternalAPIKey:          internalAPIKey,
		DriverServiceURL:        driverServiceURL,
		TripServiceURL:          tripServiceURL,
		FirebaseCredentialsFile: firebaseCredsFile,
		FirebaseCredentialsJSON: firebaseCredsJSON,
	}, nil
}
