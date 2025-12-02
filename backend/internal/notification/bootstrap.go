package notification

import (
	"context"
	"os"
	"strings"

	"uitgo/backend/internal/config"
)

// BuildSenderFromConfig loads Firebase credentials from config/env and creates an FCMSender.
func BuildSenderFromConfig(ctx context.Context, cfg *config.Config) (Sender, error) {
	if cfg == nil {
		return nil, nil
	}

	var credentials []byte
	if raw := strings.TrimSpace(cfg.FirebaseCredentialsJSON); raw != "" {
		credentials = []byte(raw)
	} else if path := strings.TrimSpace(cfg.FirebaseCredentialsFile); path != "" {
		data, err := os.ReadFile(path)
		if err != nil {
			return nil, err
		}
		credentials = data
	}

	if len(credentials) == 0 {
		return nil, nil
	}

	return NewFCMSender(ctx, credentials)
}
