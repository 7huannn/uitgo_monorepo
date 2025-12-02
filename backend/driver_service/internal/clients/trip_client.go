package clients

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"uitgo/backend/internal/domain"
)

// TripClient talks to the trip-service to coordinate assignments and statuses.
type TripClient struct {
	baseURL string
	apiKey  string
	client  *http.Client
}

// NewTripClient creates a TripClient instance.
func NewTripClient(baseURL, apiKey string) *TripClient {
	trimmed := strings.TrimSpace(baseURL)
	trimmed = strings.TrimSuffix(trimmed, "/")
	return &TripClient{
		baseURL: trimmed,
		apiKey:  apiKey,
		client:  &http.Client{Timeout: 5 * time.Second},
	}
}

var _ domain.TripSyncRepository = (*TripClient)(nil)

// GetTrip fetches the latest trip snapshot.
func (c *TripClient) GetTrip(id string) (*domain.Trip, error) {
	if c.baseURL == "" {
		return nil, errors.New("trip service url not configured")
	}
	endpoint := fmt.Sprintf("%s/internal/trips/%s", c.baseURL, id)
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	c.applyHeaders(req)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, domain.ErrTripNotFound
	}
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		return nil, fmt.Errorf("trip service error: %s", strings.TrimSpace(string(body)))
	}

	var trip domain.Trip
	if err := json.NewDecoder(resp.Body).Decode(&trip); err != nil {
		return nil, err
	}
	return &trip, nil
}

// UpdateTripStatus forwards the status change to the trip-service.
func (c *TripClient) UpdateTripStatus(id string, status domain.TripStatus) error {
	if c.baseURL == "" {
		return errors.New("trip service url not configured")
	}
	body, _ := json.Marshal(map[string]string{"status": string(status)})
	endpoint := fmt.Sprintf("%s/internal/trips/%s/status", c.baseURL, id)
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	c.applyHeaders(req)

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return domain.ErrTripNotFound
	}
	if resp.StatusCode >= 300 {
		payload, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		return fmt.Errorf("trip service error: %s", strings.TrimSpace(string(payload)))
	}
	return nil
}

// SetTripDriver assigns/unassigns a driver on the trip-service.
func (c *TripClient) SetTripDriver(id string, driverID *string) error {
	if c.baseURL == "" {
		return errors.New("trip service url not configured")
	}
	payload := map[string]*string{"driverId": driverID}
	body, _ := json.Marshal(payload)
	endpoint := fmt.Sprintf("%s/internal/trips/%s/driver", c.baseURL, id)
	req, err := http.NewRequest(http.MethodPatch, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	c.applyHeaders(req)

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return domain.ErrTripNotFound
	}
	if resp.StatusCode >= 300 {
		payload, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		return fmt.Errorf("trip service error: %s", strings.TrimSpace(string(payload)))
	}
	return nil
}

func (c *TripClient) applyHeaders(req *http.Request) {
	if c.apiKey != "" {
		req.Header.Set("X-Internal-Token", c.apiKey)
	}
}
