package main

import (
	"log"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/http"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	pool, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}
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
