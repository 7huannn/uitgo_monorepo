package main

import (
	"log"
	"os"
	"path/filepath"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/user_service/internal/clients"
	"uitgo/backend/user_service/internal/server"
)

const containerMigrationsPath = "/app/migrations"

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	pool, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}

	if err := db.Migrate(pool, resolveMigrationsPath()); err != nil {
		log.Fatalf("run migrations: %v", err)
	}
	log.Println("user-service migrations applied")

	sqlDB, err := pool.DB()
	if err != nil {
		log.Fatalf("db handle: %v", err)
	}
	defer sqlDB.Close()

	var driverProvisioner handlers.DriverProvisioner
	if cfg.DriverServiceURL != "" {
		driverProvisioner = clients.NewDriverClient(cfg.DriverServiceURL, cfg.InternalAPIKey)
	}

	srv, err := server.New(cfg, pool, driverProvisioner)
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
	return filepath.Join("backend", "user_service", "migrations")
}
