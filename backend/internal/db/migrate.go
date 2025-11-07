package db

import (
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"

	"gorm.io/gorm"
)

// Migrate executes SQL migration files located in dir.
func Migrate(db *gorm.DB, dir string) error {
	stat, err := os.Stat(dir)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("migrations directory %s not found", dir)
		}
		return fmt.Errorf("stat migrations dir: %w", err)
	}
	if !stat.IsDir() {
		return fmt.Errorf("migrations path %s is not a directory", dir)
	}

	files, err := filepath.Glob(filepath.Join(dir, "*.sql"))
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}
	sort.Strings(files)

	if len(files) == 0 {
		return fmt.Errorf("no migration files found in %s", dir)
	}

	for _, file := range files {
		sqlBytes, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", file, err)
		}
		log.Printf("applying migration: %s", filepath.Base(file))
		if err := db.Exec(string(sqlBytes)).Error; err != nil {
			return fmt.Errorf("execute migration %s: %w", file, err)
		}
	}
	return nil
}
