package matching

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// QueueOptions encapsulates configuration for queue backends.
type QueueOptions struct {
	Backend              string
	RedisAddr            string
	RedisPassword        string
	RedisDB              int
	QueueName            string
	SQSQueueURL          string
	SQSRegion            string
	SQSVisibilityTimeout time.Duration
	SQSWaitTime          time.Duration
	SQSMaxMessages       int32
	SQSClient            SQSAPI
}

// NewQueue provisions the requested queue backend.
func NewQueue(ctx context.Context, opts QueueOptions) (Queue, error) {
	backend := strings.TrimSpace(strings.ToLower(opts.Backend))
	if backend == "" || backend == "redis" {
		return NewRedisQueue(opts.RedisAddr, opts.RedisPassword, opts.RedisDB, opts.QueueName)
	}
	if backend == "sqs" {
		if opts.SQSQueueURL == "" {
			return nil, fmt.Errorf("matching: sqs queue url required")
		}
		cfg := SQSConfig{
			QueueURL:          opts.SQSQueueURL,
			Region:            opts.SQSRegion,
			Client:            opts.SQSClient,
			VisibilityTimeout: opts.SQSVisibilityTimeout,
			WaitTime:          opts.SQSWaitTime,
			MaxMessages:       opts.SQSMaxMessages,
		}
		return NewSQSQueue(ctx, cfg)
	}
	return nil, fmt.Errorf("matching: unsupported queue backend %q", opts.Backend)
}
