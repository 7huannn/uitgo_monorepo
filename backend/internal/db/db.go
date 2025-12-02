package db

import (
	"errors"
	"log"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Connect establishes a GORM database connection.
func Connect(dsn string) (*gorm.DB, error) {
	if dsn == "" {
		return nil, errors.New("POSTGRES_DSN missing")
	}
	cfg := &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	}

	db, err := gorm.Open(postgres.Open(dsn), cfg)
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetMaxOpenConns(20)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)

	if err := sqlDB.Ping(); err != nil {
		return nil, err
	}

	log.Println("database connection established")
	return db, nil
}
