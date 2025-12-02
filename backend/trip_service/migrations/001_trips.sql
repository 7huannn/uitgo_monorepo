CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id TEXT NOT NULL,
    driver_id TEXT,
    service_id TEXT NOT NULL,
    origin_text TEXT NOT NULL,
    dest_text TEXT NOT NULL,
    origin_lat DOUBLE PRECISION,
    origin_lng DOUBLE PRECISION,
    dest_lat DOUBLE PRECISION,
    dest_lng DOUBLE PRECISION,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trips_rider ON trips (rider_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips (driver_id);

CREATE TABLE IF NOT EXISTS trip_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trip_events_trip ON trip_events (trip_id, created_at DESC);
