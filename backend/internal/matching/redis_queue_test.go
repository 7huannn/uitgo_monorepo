package matching

import (
	"context"
	"errors"
	"syscall"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	"github.com/stretchr/testify/require"
)

func TestRedisQueuePublishConsume(t *testing.T) {
	server, err := miniredis.Run()
	if err != nil {
		if errors.Is(err, syscall.EPERM) {
			t.Skip("sockets not permitted in this environment")
		}
		require.NoError(t, err)
	}
	defer server.Close()

	queue, err := NewRedisQueue(server.Addr(), "", 0, "test:queue")
	require.NoError(t, err)
	defer queue.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	events := make(chan *TripEvent, 1)
	done := make(chan error, 1)
	go func() {
		err := queue.Consume(ctx, func(ctx context.Context, event *TripEvent) error {
			events <- event
			cancel()
			return nil
		})
		done <- err
	}()

	event := &TripEvent{
		TripID:    "trip-1",
		RiderID:   "rider-1",
		ServiceID: "bike",
	}
	require.NoError(t, queue.Publish(context.Background(), event))

	select {
	case evt := <-events:
		require.Equal(t, "trip-1", evt.TripID)
		require.Equal(t, "rider-1", evt.RiderID)
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for redis consumer event")
	}

	select {
	case err := <-done:
		require.ErrorIs(t, err, context.Canceled)
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for redis consumer")
	}
}
