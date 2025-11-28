package matching

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
)

// SQSAPI captures the subset of the SQS client we rely on (for mocking).
type SQSAPI interface {
	SendMessage(ctx context.Context, params *sqs.SendMessageInput, optFns ...func(*sqs.Options)) (*sqs.SendMessageOutput, error)
	ReceiveMessage(ctx context.Context, params *sqs.ReceiveMessageInput, optFns ...func(*sqs.Options)) (*sqs.ReceiveMessageOutput, error)
	DeleteMessage(ctx context.Context, params *sqs.DeleteMessageInput, optFns ...func(*sqs.Options)) (*sqs.DeleteMessageOutput, error)
}

// SQSConfig describes how to connect to SQS.
type SQSConfig struct {
	QueueURL          string
	Region            string
	Client            SQSAPI
	VisibilityTimeout time.Duration
	WaitTime          time.Duration
	MaxMessages       int32
}

// SQSQueue provides an SQS-backed queue.
type SQSQueue struct {
	client            SQSAPI
	queueURL          string
	waitTimeSeconds   int32
	visibilitySeconds int32
	maxMessages       int32
}

// NewSQSQueue builds an SQS queue using explicit client or AWS default config.
func NewSQSQueue(ctx context.Context, cfg SQSConfig) (*SQSQueue, error) {
	if cfg.QueueURL == "" {
		return nil, errors.New("sqs queue url required")
	}
	client := cfg.Client
	if client == nil {
		if cfg.Region == "" {
			return nil, errors.New("aws region required for sqs backend")
		}
		awsCfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(cfg.Region))
		if err != nil {
			return nil, fmt.Errorf("load aws config: %w", err)
		}
		client = sqs.NewFromConfig(awsCfg)
	}
	wait := clampDuration(cfg.WaitTime, 10*time.Second, 20*time.Second)
	visibility := clampDuration(cfg.VisibilityTimeout, 30*time.Second, 12*time.Hour)
	maxMessages := cfg.MaxMessages
	if maxMessages <= 0 || maxMessages > 10 {
		maxMessages = 1
	}
	return &SQSQueue{
		client:            client,
		queueURL:          cfg.QueueURL,
		waitTimeSeconds:   int32(wait / time.Second),
		visibilitySeconds: int32(visibility / time.Second),
		maxMessages:       maxMessages,
	}, nil
}

// Publish enqueues the trip event.
func (q *SQSQueue) Publish(ctx context.Context, event *TripEvent) error {
	if q == nil {
		return errors.New("queue not configured")
	}
	if event == nil || event.TripID == "" {
		return errors.New("trip event required")
	}
	body, err := json.Marshal(event)
	if err != nil {
		return err
	}
	_, err = q.client.SendMessage(ctx, &sqs.SendMessageInput{
		QueueUrl:    aws.String(q.queueURL),
		MessageBody: aws.String(string(body)),
	})
	return err
}

// Consume polls SQS for new trip events.
func (q *SQSQueue) Consume(ctx context.Context, handler TripEventHandler) error {
	if q == nil {
		return errors.New("queue not configured")
	}
	if handler == nil {
		return errors.New("handler required")
	}
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		resp, err := q.client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(q.queueURL),
			MaxNumberOfMessages: q.maxMessages,
			WaitTimeSeconds:     q.waitTimeSeconds,
			VisibilityTimeout:   q.visibilitySeconds,
		})
		if err != nil {
			if errors.Is(err, context.Canceled) {
				return err
			}
			log.Printf("trip queue sqs receive error: %v", err)
			time.Sleep(time.Second)
			continue
		}
		if len(resp.Messages) == 0 {
			continue
		}
		for _, msg := range resp.Messages {
			processSQSMessage(ctx, q, &msg, handler)
		}
	}
}

func processSQSMessage(ctx context.Context, q *SQSQueue, msg *types.Message, handler TripEventHandler) {
	if msg == nil || msg.Body == nil || msg.ReceiptHandle == nil {
		return
	}
	var event TripEvent
	if err := json.Unmarshal([]byte(*msg.Body), &event); err != nil {
		log.Printf("trip queue sqs decode error: %v", err)
		return
	}
	if err := handler(ctx, &event); err != nil {
		log.Printf("trip queue handler error: %v", err)
		return
	}
	if _, err := q.client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(q.queueURL),
		ReceiptHandle: msg.ReceiptHandle,
	}); err != nil {
		log.Printf("trip queue sqs delete error: %v", err)
	}
}

// Close satisfies the Queue interface (SQS client does not need shutdown).
func (q *SQSQueue) Close() error {
	return nil
}

func clampDuration(value time.Duration, def time.Duration, max time.Duration) time.Duration {
	if value <= 0 {
		return def
	}
	if max > 0 && value > max {
		return max
	}
	return value
}

var _ Queue = (*SQSQueue)(nil)
