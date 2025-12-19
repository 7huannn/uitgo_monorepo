ALTER TABLE users
    ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'rider';

-- Seed driver is removed to avoid cross-database type conflicts during migration.
-- Use application-level registration or admin tools to create driver accounts.
