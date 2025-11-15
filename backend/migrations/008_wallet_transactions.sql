CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    amount BIGINT NOT NULL CHECK (amount >= 0),
    type TEXT NOT NULL CHECK (type IN ('topup', 'reward', 'deduction')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created_at
    ON wallet_transactions (user_id, created_at DESC);

ALTER TABLE wallets
    ALTER COLUMN balance SET NOT NULL,
    ALTER COLUMN reward_points SET NOT NULL,
    ALTER COLUMN updated_at SET NOT NULL;
