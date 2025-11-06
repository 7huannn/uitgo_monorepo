package main

import (
	"log"
	"path/filepath"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	conn, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect db: %v", err)
	}

	sqlDB, err := conn.DB()
	if err != nil {
		log.Fatalf("sql db: %v", err)
	}
	defer sqlDB.Close()

	migrationsPath := filepath.Join("backend", "migrations")
	if err := db.Migrate(conn, migrationsPath); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	log.Println("migrations applied")
}
