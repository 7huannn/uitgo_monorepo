package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"uitgo/backend/internal/domain"
)

// DriverClient calls the driver-service over HTTP to provision driver profiles.
type DriverClient struct {
	baseURL     string
	internalKey string
	httpClient  *http.Client
}

// NewDriverClient creates a DriverClient. When baseURL is empty the client returns an error on use.
func NewDriverClient(baseURL, internalKey string) *DriverClient {
	trimmed := strings.TrimSpace(baseURL)
	trimmed = strings.TrimSuffix(trimmed, "/")
	return &DriverClient{
		baseURL:     trimmed,
		internalKey: internalKey,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

var _ interface {
	Register(ctx context.Context, userID string, input domain.DriverRegistrationInput) (*domain.Driver, error)
} = (*DriverClient)(nil)

// Register forwards the onboarding request to the driver-service internal API.
func (c *DriverClient) Register(ctx context.Context, userID string, input domain.DriverRegistrationInput) (*domain.Driver, error) {
	if c == nil || c.baseURL == "" {
		return nil, errors.New("driver service url not configured")
	}
	payload := map[string]any{
		"userId":        userID,
		"fullName":      strings.TrimSpace(input.FullName),
		"phone":         strings.TrimSpace(input.Phone),
		"licenseNumber": strings.TrimSpace(input.LicenseNumber),
	}
	if input.AvatarURL != nil && strings.TrimSpace(*input.AvatarURL) != "" {
		payload["avatarUrl"] = strings.TrimSpace(*input.AvatarURL)
	}
	if input.Vehicle != nil {
		vehicle := map[string]any{}
		if v := strings.TrimSpace(input.Vehicle.Make); v != "" {
			vehicle["make"] = v
		}
		if v := strings.TrimSpace(input.Vehicle.Model); v != "" {
			vehicle["model"] = v
		}
		if v := strings.TrimSpace(input.Vehicle.Color); v != "" {
			vehicle["color"] = v
		}
		if input.Vehicle.Year != 0 {
			vehicle["year"] = input.Vehicle.Year
		}
		if v := strings.TrimSpace(input.Vehicle.PlateNumber); v != "" {
			vehicle["plateNumber"] = v
		}
		if len(vehicle) > 0 {
			payload["vehicle"] = vehicle
		}
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s/internal/drivers", c.baseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if c.internalKey != "" {
		req.Header.Set("X-Internal-Token", c.internalKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		// Preserve domain-level conflicts so the caller can map to 409 instead of 500.
		if resp.StatusCode == http.StatusConflict {
			msg := strings.ToLower(strings.TrimSpace(string(data)))
			switch {
			case strings.Contains(msg, "driver already exists"):
				return nil, domain.ErrDriverAlreadyExists
			case strings.Contains(msg, "vehicle already exists"):
				return nil, domain.ErrVehicleAlreadyExists
			default:
				return nil, domain.ErrDriverAlreadyExists
			}
		}
		if len(data) == 0 {
			return nil, fmt.Errorf("driver service error: %s", resp.Status)
		}
		return nil, fmt.Errorf("driver service error: %s", strings.TrimSpace(string(data)))
	}

	var driver domain.Driver
	if err := json.NewDecoder(resp.Body).Decode(&driver); err != nil {
		return nil, err
	}
	return &driver, nil
}
