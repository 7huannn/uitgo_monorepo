package main

import (
	"log"
	"os"
	"path/filepath"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/logging"
	"uitgo/backend/internal/observability"
	"uitgo/backend/trip_service/internal/clients"
	"uitgo/backend/trip_service/internal/server"
)

const containerMigrationsPath = "/app/migrations"

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	logging.Configure(cfg.LogFormat, "trip-service")
	flushSentry := observability.InitSentry(cfg.SentryDSN, "trip-service")
	defer flushSentry()

	pool, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}

	if err := db.Migrate(pool, resolveMigrationsPath()); err != nil {
		log.Fatalf("run migrations: %v", err)
	}
	log.Println("trip-service migrations applied")

	sqlDB, err := pool.DB()
	if err != nil {
		log.Fatalf("db handle: %v", err)
	}
	defer sqlDB.Close()

	var locationWriter handlers.DriverLocationWriter
	if cfg.DriverServiceURL != "" {
		locationWriter = clients.NewLocationClient(cfg.DriverServiceURL, cfg.InternalAPIKey)
	}

	srv, err := server.New(cfg, pool, locationWriter)
	if err != nil {
		log.Fatalf("init server: %v", err)
	}

	if err := srv.Run(); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

func resolveMigrationsPath() string {
	if _, err := os.Stat(containerMigrationsPath); err == nil {
		return containerMigrationsPath
	}
	return filepath.Join("backend", "trip_service", "migrations")
}
