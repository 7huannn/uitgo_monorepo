package notification

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"uitgo/backend/internal/domain"
)

// Sender dispatches push notifications to device tokens.
type Sender interface {
	Send(ctx context.Context, tokens []string, message PushMessage) error
}

// PushMessage describes a push notification payload.
type PushMessage struct {
	Title string
	Body  string
	Data  map[string]string
}

// Service orchestrates notification persistence and push delivery.
type Service struct {
	repo   domain.NotificationRepository
	tokens domain.DeviceTokenRepository
	sender Sender
}

// Ensure Service implements TripEventNotifier for domain services.
var _ domain.TripEventNotifier = (*Service)(nil)

// NewService builds a notification service.
func NewService(repo domain.NotificationRepository, tokens domain.DeviceTokenRepository, sender Sender) *Service {
	return &Service{
		repo:   repo,
		tokens: tokens,
		sender: sender,
	}
}

// RegisterDevice stores/updates the device token for the authenticated user.
func (s *Service) RegisterDevice(ctx context.Context, userID, platform, token string) (*domain.DeviceToken, error) {
	if s.tokens == nil {
		return nil, errors.New("device token store unavailable")
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return nil, errors.New("user id required")
	}
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, errors.New("token required")
	}
	platform = normalizePlatform(platform)
	return s.tokens.Register(ctx, userID, platform, token)
}

// NotifyDriverTripAssigned sends a push notification when a driver receives a new trip.
func (s *Service) NotifyDriverTripAssigned(ctx context.Context, driver *domain.Driver, trip *domain.Trip) error {
	if s == nil || driver == nil || trip == nil || driver.UserID == "" {
		return nil
	}
	body := fmt.Sprintf("%s → %s", strings.TrimSpace(trip.OriginText), strings.TrimSpace(trip.DestText))
	if body == "→" {
		body = "You have a new trip request."
	}
	data := map[string]string{
		"event":      "trip.assigned",
		"tripId":     trip.ID,
		"tripStatus": string(trip.Status),
	}
	return s.send(ctx, driver.UserID, "trip.assigned", "New trip assigned", body, &trip.ID, data)
}

// NotifyRiderStatusChange alerts the rider when the driver arrives or when the trip completes.
func (s *Service) NotifyRiderStatusChange(ctx context.Context, trip *domain.Trip, status domain.TripStatus) error {
	if s == nil || trip == nil || trip.RiderID == "" {
		return nil
	}
	var (
		title string
		body  string
	)
	switch status {
	case domain.TripStatusArriving:
		title = "Your driver has arrived"
		body = fmt.Sprintf("Your driver is near %s.", strings.TrimSpace(trip.OriginText))
	case domain.TripStatusCompleted:
		title = "Trip completed"
		body = fmt.Sprintf("Hope you enjoyed your ride to %s.", strings.TrimSpace(trip.DestText))
	default:
		return nil
	}
	data := map[string]string{
		"event":  "trip.status",
		"status": string(status),
		"tripId": trip.ID,
	}
	return s.send(ctx, trip.RiderID, fmt.Sprintf("trip.%s", status), title, body, &trip.ID, data)
}

func (s *Service) send(ctx context.Context, userID, notifType, title, body string, tripID *string, meta map[string]string) error {
	if s == nil {
		return nil
	}

	if s.repo != nil && notifType != "" {
		notification := &domain.Notification{
			UserID: userID,
			Title:  title,
			Body:   body,
			Type:   notifType,
			TripID: tripID,
		}
		if err := s.repo.Create(ctx, notification); err != nil {
			return err
		}
	}

	if s.tokens == nil || s.sender == nil {
		return nil
	}

	tokens, err := s.tokens.ListByUsers(ctx, []string{userID})
	if err != nil {
		return err
	}
	if len(tokens) == 0 {
		return nil
	}

	payload := make(map[string]string, len(meta))
	for k, v := range meta {
		payload[k] = v
	}
	if tripID != nil {
		payload["tripId"] = *tripID
	}
	message := PushMessage{
		Title: title,
		Body:  body,
		Data:  payload,
	}
	pushTokens := make([]string, 0, len(tokens))
	for _, token := range tokens {
		if trimmed := strings.TrimSpace(token.Token); trimmed != "" {
			pushTokens = append(pushTokens, trimmed)
		}
	}
	if len(pushTokens) == 0 {
		return nil
	}
	if err := s.sender.Send(ctx, pushTokens, message); err != nil {
		return err
	}
	return nil
}

func normalizePlatform(platform string) string {
	normalized := strings.TrimSpace(strings.ToLower(platform))
	switch normalized {
	case "ios", "android", "web":
		return normalized
	default:
		return "unknown"
	}
}
