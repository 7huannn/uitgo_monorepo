package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/logging"
	"uitgo/backend/internal/matching"
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
	shutdownTracer := observability.InitTracing(context.Background(), "trip-service", cfg.TracingEndpoint)
	defer shutdownTracer(context.Background())

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

	readDB := pool
	var replicaSQLClose func()
	if cfg.TripReplicaDatabaseURL != "" {
		replica, err := db.Connect(cfg.TripReplicaDatabaseURL)
		if err != nil {
			log.Fatalf("connect replica database: %v", err)
		}
		readDB = replica
		if replicaSQL, err := replica.DB(); err == nil {
			replicaSQLClose = func() {
				_ = replicaSQL.Close()
			}
		} else {
			log.Printf("warn: replica db handle: %v", err)
		}
	}
	if replicaSQLClose != nil {
		defer replicaSQLClose()
	}

	var locationWriter handlers.DriverLocationWriter
	if cfg.DriverServiceURL != "" {
		locationWriter = clients.NewLocationClient(cfg.DriverServiceURL, cfg.InternalAPIKey)
	}

	var dispatcher matching.TripDispatcher
	queue, err := matching.NewQueue(context.Background(), matching.QueueOptions{
		Backend:       cfg.MatchQueueBackend,
		RedisAddr:     cfg.MatchQueueAddr,
		RedisPassword: cfg.RedisPassword,
		RedisDB:       cfg.MatchQueueDB,
		QueueName:     cfg.MatchQueueName,
		SQSQueueURL:   cfg.MatchQueueSQSURL,
		SQSRegion:     cfg.AWSRegion,
	})
	if err != nil {
		log.Printf("warn: unable to initialize trip queue: %v", err)
	} else if queue != nil {
		dispatcher = queue
		defer queue.Close()
	}

	var walletOps domain.WalletOperations
	if cfg.UserServiceURL != "" {
		walletOps = clients.NewWalletClient(cfg.UserServiceURL, cfg.InternalAPIKey)
	} else {
		log.Printf("warn: user service url not configured; wallet enforcement disabled")
	}

	srv, err := server.New(cfg, pool, readDB, locationWriter, dispatcher, walletOps)
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
