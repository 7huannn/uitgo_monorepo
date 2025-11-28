package matching

import (
	"context"
	"time"
)

// TripEvent captures payloads pushed onto the async matching queue.
type TripEvent struct {
	TripID     string    `json:"tripId"`
	RiderID    string    `json:"riderId"`
	ServiceID  string    `json:"serviceId"`
	OriginText string    `json:"originText"`
	DestText   string    `json:"destText"`
	Requested  time.Time `json:"requestedAt"`
}

// TripDispatcher publishes trip events for asynchronous processing.
type TripDispatcher interface {
	Publish(ctx context.Context, event *TripEvent) error
}

// TripEventHandler processes a single trip event from the matching queue.
type TripEventHandler func(ctx context.Context, event *TripEvent) error

// TripConsumer consumes trip events.
type TripConsumer interface {
	Consume(ctx context.Context, handler TripEventHandler) error
}

// Queue represents a matching backend that can dispatch and consume events.
type Queue interface {
	TripDispatcher
	TripConsumer
	Close() error
}
