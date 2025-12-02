package cache

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"

	"uitgo/backend/internal/domain"
)

// HomeCache wraps a Redis client for caching home metadata.
type HomeCache struct {
	client *redis.Client
	ttl    time.Duration
}

func ctxOrBackground(ctx context.Context) context.Context {
	if ctx == nil {
		return context.Background()
	}
	return ctx
}

// NewHomeCache initialises the cache when addr/ttl are provided.
func NewHomeCache(addr, password string, db int, ttl time.Duration) (*HomeCache, error) {
	if addr == "" || ttl <= 0 {
		return nil, nil
	}
	options := &redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	}
	client := redis.NewClient(options)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		client.Close()
		return nil, err
	}
	return &HomeCache{client: client, ttl: ttl}, nil
}

func (c *HomeCache) enabled() bool {
	return c != nil && c.client != nil && c.ttl > 0
}

func (c *HomeCache) get(ctx context.Context, key string, dest interface{}) (bool, error) {
	if !c.enabled() {
		return false, nil
	}
	ctx = ctxOrBackground(ctx)
	payload, err := c.client.Get(ctx, key).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return false, nil
		}
		return false, err
	}
	if err := json.Unmarshal(payload, dest); err != nil {
		return false, err
	}
	return true, nil
}

func (c *HomeCache) set(ctx context.Context, key string, value interface{}) error {
	if !c.enabled() {
		return nil
	}
	ctx = ctxOrBackground(ctx)
	payload, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return c.client.Set(ctx, key, payload, c.ttl).Err()
}

// Close shuts down the redis client.
func (c *HomeCache) Close() error {
	if c == nil || c.client == nil {
		return nil
	}
	return c.client.Close()
}

type cachedPromotionRepository struct {
	primary domain.PromotionRepository
	cache   *HomeCache
}

// NewCachedPromotionRepository decorates the promotion repository with Redis cache.
func NewCachedPromotionRepository(repo domain.PromotionRepository, cache *HomeCache) domain.PromotionRepository {
	if repo == nil || cache == nil || !cache.enabled() {
		return repo
	}
	return &cachedPromotionRepository{primary: repo, cache: cache}
}

func (r *cachedPromotionRepository) ListActive(ctx context.Context) ([]*domain.Promotion, error) {
	const key = "home:promotions"
	var cached []*domain.Promotion
	if ok, err := r.cache.get(ctx, key, &cached); err == nil && ok {
		return cached, nil
	} else if err != nil {
		log.Printf("warn: promotions cache get failed: %v", err)
	}

	items, err := r.primary.ListActive(ctx)
	if err != nil {
		return nil, err
	}
	if err := r.cache.set(ctx, key, items); err != nil {
		log.Printf("warn: promotions cache set failed: %v", err)
	}
	return items, nil
}

func (r *cachedPromotionRepository) ListAll(ctx context.Context) ([]*domain.Promotion, error) {
	return r.primary.ListAll(ctx)
}

func (r *cachedPromotionRepository) Create(ctx context.Context, promo *domain.Promotion) (*domain.Promotion, error) {
	result, err := r.primary.Create(ctx, promo)
	if err != nil {
		return nil, err
	}
	if err := r.cache.client.Del(ctxOrBackground(ctx), "home:promotions").Err(); err != nil && !errors.Is(err, redis.Nil) {
		log.Printf("warn: promotions cache invalidate failed: %v", err)
	}
	return result, nil
}

func (r *cachedPromotionRepository) Deactivate(ctx context.Context, id string) error {
	if err := r.primary.Deactivate(ctx, id); err != nil {
		return err
	}
	if err := r.cache.client.Del(ctxOrBackground(ctx), "home:promotions").Err(); err != nil && !errors.Is(err, redis.Nil) {
		log.Printf("warn: promotions cache invalidate failed: %v", err)
	}
	return nil
}

type cachedNewsRepository struct {
	primary domain.NewsRepository
	cache   *HomeCache
}

// NewCachedNewsRepository decorates the news repository with Redis cache.
func NewCachedNewsRepository(repo domain.NewsRepository, cache *HomeCache) domain.NewsRepository {
	if repo == nil || cache == nil || !cache.enabled() {
		return repo
	}
	return &cachedNewsRepository{primary: repo, cache: cache}
}

func (r *cachedNewsRepository) ListLatest(ctx context.Context, limit int) ([]*domain.NewsItem, error) {
	key := "home:news:" + strconv.Itoa(limit)
	var cached []*domain.NewsItem
	if ok, err := r.cache.get(ctx, key, &cached); err == nil && ok {
		return cached, nil
	} else if err != nil {
		log.Printf("warn: news cache get failed: %v", err)
	}

	items, err := r.primary.ListLatest(ctx, limit)
	if err != nil {
		return nil, err
	}
	if err := r.cache.set(ctx, key, items); err != nil {
		log.Printf("warn: news cache set failed: %v", err)
	}
	return items, nil
}
