package matching

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisQueue implements TripDispatcher and TripConsumer.
type RedisQueue struct {
	client  *redis.Client
	queue   string
	timeout time.Duration
}

// NewRedisQueue creates a Redis backed queue.
func NewRedisQueue(addr, password string, db int, queue string) (*RedisQueue, error) {
	if addr == "" {
		return nil, errors.New("redis address required")
	}
	key := queue
	if key == "" {
		key = "trip:requests"
	}
	opts := &redis.Options{Addr: addr, Password: password, DB: db}
	client := redis.NewClient(opts)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		client.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}
	return &RedisQueue{client: client, queue: key, timeout: 5 * time.Second}, nil
}

// Close shuts down the Redis client.
func (q *RedisQueue) Close() error {
	if q == nil || q.client == nil {
		return nil
	}
	return q.client.Close()
}

// Publish enqueues a new trip event.
func (q *RedisQueue) Publish(ctx context.Context, event *TripEvent) error {
	if q == nil {
		return errors.New("queue not configured")
	}
	if event == nil || event.TripID == "" {
		return errors.New("trip event required")
	}
	payload, err := json.Marshal(event)
	if err != nil {
		return err
	}
	if ctx == nil {
		ctx = context.Background()
	}
	return q.client.RPush(ctx, q.queue, payload).Err()
}

// Consume blocks and delivers trip events to handler until ctx is cancelled.
func (q *RedisQueue) Consume(ctx context.Context, handler TripEventHandler) error {
	if q == nil {
		return errors.New("queue not configured")
	}
	if handler == nil {
		return errors.New("handler required")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		result, err := q.client.BRPop(ctx, q.timeout, q.queue).Result()
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, redis.Nil) {
				continue
			}
			log.Printf("trip queue brpop error: %v", err)
			time.Sleep(time.Second)
			continue
		}
		if len(result) != 2 {
			continue
		}
		var event TripEvent
		if err := json.Unmarshal([]byte(result[1]), &event); err != nil {
			log.Printf("trip queue decode error: %v", err)
			continue
		}
		if err := handler(ctx, &event); err != nil {
			log.Printf("trip queue handler error: %v", err)
		}
	}
}

var _ Queue = (*RedisQueue)(nil)
