package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"uitgo/backend/driver_service/internal/clients"
	"uitgo/backend/driver_service/internal/server"
	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/logging"
	"uitgo/backend/internal/observability"
)

const (
	containerMigrationsPath = "/app/migrations"
	serviceName             = "driver-service"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	logging.Configure(cfg.LogFormat, serviceName)
	flushSentry := observability.InitSentry(cfg.SentryDSN, serviceName)
	defer flushSentry()
	shutdownTracer := observability.InitTracing(context.Background(), serviceName, cfg.TracingEndpoint)
	defer shutdownTracer(context.Background())

	pool, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}

	if err := db.Migrate(pool, resolveMigrationsPath()); err != nil {
		log.Fatalf("run migrations: %v", err)
	}
	log.Println(serviceName + " migrations applied")

	sqlDB, err := pool.DB()
	if err != nil {
		log.Fatalf("db handle: %v", err)
	}
	defer sqlDB.Close()

	var tripSync domain.TripSyncRepository
	if cfg.TripServiceURL != "" {
		tripSync = clients.NewTripClient(cfg.TripServiceURL, cfg.InternalAPIKey)
	}

	srv, err := server.New(cfg, pool, tripSync)
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
	return filepath.Join("backend", "driver_service", "migrations")
}
