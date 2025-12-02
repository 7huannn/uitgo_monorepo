package location

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"

	"uitgo/backend/internal/domain"
)

// GeoIndex maintains driver coordinates inside Redis GEO structures.
type GeoIndex struct {
	client  *redis.Client
	geoKey  string
	metaKey string
}

// NewGeoIndex connects to Redis and prepares GEO + metadata keys.
func NewGeoIndex(addr, password string, db int, scope string) (*GeoIndex, error) {
	if addr == "" {
		return nil, errors.New("redis addr required")
	}
	opts := &redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	}
	client := redis.NewClient(opts)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		client.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}
	prefix := "driver"
	if scope != "" {
		prefix = scope
	}
	return &GeoIndex{
		client:  client,
		geoKey:  fmt.Sprintf("%s:locations", prefix),
		metaKey: fmt.Sprintf("%s:locations:meta", prefix),
	}, nil
}

// Close releases the underlying Redis connection.
func (g *GeoIndex) Close() error {
	if g == nil || g.client == nil {
		return nil
	}
	return g.client.Close()
}

// Upsert records the driver's latest coordinates inside Redis.
func (g *GeoIndex) Upsert(ctx context.Context, driverID string, location *domain.DriverLocation) error {
	if g == nil {
		return errors.New("geo index not configured")
	}
	if location == nil {
		return errors.New("location required")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	recorded := location.RecordedAt
	if recorded.IsZero() {
		recorded = time.Now().UTC()
	}
	geo := &redis.GeoLocation{
		Name:      driverID,
		Longitude: location.Longitude,
		Latitude:  location.Latitude,
	}
	pipe := g.client.Pipeline()
	pipe.GeoAdd(ctx, g.geoKey, geo)
	pipe.HSet(ctx, g.metaKey, driverID, recorded.Unix())
	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("redis geoadd: %w", err)
	}
	return nil
}

// Remove deletes the driver's entry from the GEO set.
func (g *GeoIndex) Remove(ctx context.Context, driverID string) error {
	if g == nil {
		return errors.New("geo index not configured")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	pipe := g.client.Pipeline()
	pipe.ZRem(ctx, g.geoKey, driverID)
	pipe.HDel(ctx, g.metaKey, driverID)
	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("redis remove driver %s: %w", driverID, err)
	}
	return nil
}

// Nearby returns the closest drivers to the provided coordinate.
func (g *GeoIndex) Nearby(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]*domain.DriverLocation, error) {
	if g == nil {
		return nil, errors.New("geo index not configured")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	if radiusMeters <= 0 {
		radiusMeters = 3000
	}
	if limit <= 0 {
		limit = 10
	}
	query := &redis.GeoSearchLocationQuery{
		GeoSearchQuery: redis.GeoSearchQuery{
			Longitude:  lng,
			Latitude:   lat,
			Radius:     radiusMeters,
			RadiusUnit: "m",
			Sort:       "ASC",
			Count:      limit,
		},
		WithDist: true,
	}
	raw, err := g.client.GeoSearchLocation(ctx, g.geoKey, query).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return []*domain.DriverLocation{}, nil
		}
		return nil, fmt.Errorf("redis geosearch: %w", err)
	}
	if len(raw) == 0 {
		return []*domain.DriverLocation{}, nil
	}
	ids := make([]string, 0, len(raw))
	for _, item := range raw {
		if item.Name != "" {
			ids = append(ids, item.Name)
		}
	}
	timestamps := map[string]time.Time{}
	if len(ids) > 0 {
		meta, err := g.client.HMGet(ctx, g.metaKey, ids...).Result()
		if err == nil {
			for idx, value := range meta {
				ts := parseTimestamp(value)
				if !ts.IsZero() {
					timestamps[ids[idx]] = ts
				}
			}
		}
	}
	locations := make([]*domain.DriverLocation, 0, len(raw))
	for _, item := range raw {
		if item.Name == "" {
			continue
		}
		recordedAt := timestamps[item.Name]
		if recordedAt.IsZero() {
			recordedAt = time.Now().UTC()
		}
		loc := &domain.DriverLocation{
			DriverID:   item.Name,
			Latitude:   item.Latitude,
			Longitude:  item.Longitude,
			RecordedAt: recordedAt,
		}
		if item.Dist > 0 {
			distance := item.Dist
			loc.DistanceMeters = &distance
		}
		locations = append(locations, loc)
	}
	return locations, nil
}

func parseTimestamp(value interface{}) time.Time {
	switch v := value.(type) {
	case string:
		if v == "" {
			return time.Time{}
		}
		if parsed, err := strconv.ParseInt(v, 10, 64); err == nil {
			return time.Unix(parsed, 0).UTC()
		}
	case []byte:
		if len(v) == 0 {
			return time.Time{}
		}
		if parsed, err := strconv.ParseInt(string(v), 10, 64); err == nil {
			return time.Unix(parsed, 0).UTC()
		}
	case int64:
		return time.Unix(v, 0).UTC()
	case int:
		return time.Unix(int64(v), 0).UTC()
	case float64:
		return time.Unix(int64(v), 0).UTC()
	}
	return time.Time{}
}

var _ domain.DriverLocationIndex = (*GeoIndex)(nil)
