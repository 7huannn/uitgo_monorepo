CREATE TABLE IF NOT EXISTS trip_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL UNIQUE,
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trip_assignments_driver ON trip_assignments (driver_id);
