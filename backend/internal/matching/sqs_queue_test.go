package matching

import (
	"context"
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/stretchr/testify/require"
)

func TestSQSQueuePublishConsume(t *testing.T) {
	mock := newMockSQS()
	queue, err := NewSQSQueue(context.Background(), SQSConfig{
		QueueURL:    "https://example.com/queue/test",
		Client:      mock,
		MaxMessages: 1,
	})
	require.NoError(t, err)

	event := &TripEvent{TripID: "trip-123", RiderID: "rider-5"}
	require.NoError(t, queue.Publish(context.Background(), event))

	require.Len(t, mock.sentMessages, 1)
	var payload TripEvent
	require.NoError(t, json.Unmarshal([]byte(*mock.sentMessages[0].MessageBody), &payload))
	require.Equal(t, event.TripID, payload.TripID)

	mock.enqueueMessage(event)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() {
		done <- queue.Consume(ctx, func(ctx context.Context, evt *TripEvent) error {
			require.Equal(t, event.TripID, evt.TripID)
			cancel()
			return nil
		})
	}()

	select {
	case err := <-done:
		require.ErrorIs(t, err, context.Canceled)
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for sqs consumer")
	}

	require.Len(t, mock.deletedMessages, 1)
	require.Equal(t, "handle-1", *mock.deletedMessages[0].ReceiptHandle)
	require.NoError(t, queue.Close())
}

type mockSQS struct {
	mu              sync.Mutex
	sentMessages    []*sqs.SendMessageInput
	deletedMessages []*sqs.DeleteMessageInput
	pending         []types.Message
}

func newMockSQS() *mockSQS {
	return &mockSQS{}
}

func (m *mockSQS) enqueueMessage(evt *TripEvent) {
	m.mu.Lock()
	defer m.mu.Unlock()
	body, _ := json.Marshal(evt)
	handle := aws.String("handle-1")
	m.pending = append(m.pending, types.Message{
		Body:          aws.String(string(body)),
		ReceiptHandle: handle,
	})
}

func (m *mockSQS) SendMessage(ctx context.Context, params *sqs.SendMessageInput, optFns ...func(*sqs.Options)) (*sqs.SendMessageOutput, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sentMessages = append(m.sentMessages, params)
	return &sqs.SendMessageOutput{}, nil
}

func (m *mockSQS) ReceiveMessage(ctx context.Context, params *sqs.ReceiveMessageInput, optFns ...func(*sqs.Options)) (*sqs.ReceiveMessageOutput, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	resp := &sqs.ReceiveMessageOutput{
		Messages: make([]types.Message, len(m.pending)),
	}
	copy(resp.Messages, m.pending)
	m.pending = nil
	if len(resp.Messages) == 0 {
		time.Sleep(10 * time.Millisecond)
	}
	return resp, nil
}

func (m *mockSQS) DeleteMessage(ctx context.Context, params *sqs.DeleteMessageInput, optFns ...func(*sqs.Options)) (*sqs.DeleteMessageOutput, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.deletedMessages = append(m.deletedMessages, params)
	return &sqs.DeleteMessageOutput{}, nil
}
