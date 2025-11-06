package db

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"gorm.io/gorm"
)

// Migrate executes SQL migration files located in dir.
func Migrate(db *gorm.DB, dir string) error {
	files, err := filepath.Glob(filepath.Join(dir, "*.sql"))
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}
	sort.Strings(files)

	for _, file := range files {
		sqlBytes, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", file, err)
		}
		if err := db.Exec(string(sqlBytes)).Error; err != nil {
			return fmt.Errorf("execute migration %s: %w", file, err)
		}
	}
	return nil
}
