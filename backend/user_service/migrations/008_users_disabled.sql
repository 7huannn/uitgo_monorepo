-- Add disabled flag to users for admin moderation
ALTER TABLE users
ADD COLUMN IF NOT EXISTS disabled BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill existing rows (noop if default applied)
UPDATE users SET disabled = FALSE WHERE disabled IS NULL;
