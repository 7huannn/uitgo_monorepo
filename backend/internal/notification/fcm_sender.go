package notification

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// FCMSender pushes notifications via Firebase Cloud Messaging.
type FCMSender struct {
	client *messaging.Client
}

// NewFCMSender initializes the Firebase messaging client using the provided credentials JSON.
func NewFCMSender(ctx context.Context, credentialsJSON []byte) (*FCMSender, error) {
	if len(credentialsJSON) == 0 {
		return nil, fmt.Errorf("credentials json required")
	}
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsJSON(credentialsJSON))
	if err != nil {
		return nil, fmt.Errorf("init firebase app: %w", err)
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("create messaging client: %w", err)
	}
	return &FCMSender{client: client}, nil
}

// Send dispatches the notification to the provided tokens.
func (s *FCMSender) Send(ctx context.Context, tokens []string, message PushMessage) error {
	if s == nil || s.client == nil || len(tokens) == 0 {
		return nil
	}
	const chunkSize = 500
	for start := 0; start < len(tokens); start += chunkSize {
		end := start + chunkSize
		if end > len(tokens) {
			end = len(tokens)
		}
		chunk := tokens[start:end]
		payload := &messaging.MulticastMessage{
			Tokens: chunk,
			Notification: &messaging.Notification{
				Title: message.Title,
				Body:  message.Body,
			},
			Data: message.Data,
		}
		if _, err := s.client.SendEachForMulticast(ctx, payload); err != nil {
			return fmt.Errorf("send fcm multicast: %w", err)
		}
	}
	return nil
}
