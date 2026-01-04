package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/http"
	"uitgo/backend/internal/logging"
	"uitgo/backend/internal/observability"
)

const containerMigrationsPath = "/app/migrations"

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	logging.Configure(cfg.LogFormat, "api")
	flushSentry := observability.InitSentry(cfg.SentryDSN, "api")
	defer flushSentry()
	shutdownTracer := observability.InitTracing(context.Background(), "api", cfg.TracingEndpoint)
	defer shutdownTracer(context.Background())

	pool, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}

	migrationsPath := resolveMigrationsPath()
	if err := db.Migrate(pool, migrationsPath); err != nil {
		log.Fatalf("run migrations: %v", err)
	}
	log.Println("migrations applied")

	sqlDB, err := pool.DB()
	if err != nil {
		log.Fatalf("db handle: %v", err)
	}
	defer sqlDB.Close()

	server, err := http.NewServer(cfg, pool)
	if err != nil {
		log.Fatalf("init server: %v", err)
	}

	if err := server.Run(); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

func resolveMigrationsPath() string {
	if _, err := os.Stat(containerMigrationsPath); err == nil {
		return containerMigrationsPath
	}
	return filepath.Join("backend", "migrations")
}
