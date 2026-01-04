package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"uitgo/backend/internal/domain"
	"uitgo/backend/internal/http/handlers"
	"uitgo/backend/internal/observability"
)

// LocationClient pushes driver location updates to the driver-service.
type LocationClient struct {
	baseURL string
	apiKey  string
	client  *http.Client
}

// NewLocationClient constructs a LocationClient.
func NewLocationClient(baseURL, apiKey string) *LocationClient {
	trimmed := strings.TrimSpace(baseURL)
	trimmed = strings.TrimSuffix(trimmed, "/")
	return &LocationClient{
		baseURL: trimmed,
		apiKey:  apiKey,
		client: observability.NewInstrumentedClient(5 * time.Second),
	}
}

var _ handlers.DriverLocationWriter = (*LocationClient)(nil)

// RecordLocation sends the latest coordinates for a driver.
func (c *LocationClient) RecordLocation(ctx context.Context, driverID string, location *domain.DriverLocation) error {
	if c == nil || c.baseURL == "" {
		return errors.New("driver service url not configured")
	}
	if location == nil {
		return errors.New("location required")
	}
	payload := map[string]any{
		"driverId":   driverID,
		"lat":        location.Latitude,
		"lng":        location.Longitude,
		"recordedAt": location.RecordedAt,
	}
	if location.Accuracy != nil {
		payload["accuracy"] = location.Accuracy
	}
	if location.Heading != nil {
		payload["heading"] = location.Heading
	}
	if location.Speed != nil {
		payload["speed"] = location.Speed
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("%s/internal/driver-locations", c.baseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("X-Internal-Token", c.apiKey)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("driver service location error: %s", resp.Status)
	}
	return nil
}
