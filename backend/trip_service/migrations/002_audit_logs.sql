CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT,
    method TEXT NOT NULL,
    path TEXT NOT NULL,
    status_code INT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    request_id TEXT,
    outcome TEXT NOT NULL DEFAULT 'success',
    error TEXT,
    latency_ms BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user
    ON audit_logs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_path
    ON audit_logs (path, created_at DESC);
