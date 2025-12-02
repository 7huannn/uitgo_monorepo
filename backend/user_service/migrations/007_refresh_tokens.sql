CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    token_ciphertext BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);

-- Ensure column and index exist for already-created tables
ALTER TABLE refresh_tokens
    ADD COLUMN IF NOT EXISTS token_ciphertext BYTEA,
    ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user
    ON refresh_tokens (user_id, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expiry
    ON refresh_tokens (expires_at);
