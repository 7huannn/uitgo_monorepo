package domain

import (
	"context"
	"errors"
	"time"
)

// SavedPlace stores quick access pickup/destination info.
type SavedPlace struct {
	ID        string    `json:"id"`
	UserID    string    `json:"userId"`
	Name      string    `json:"name"`
	Address   string    `json:"address"`
	Latitude  float64   `json:"lat"`
	Longitude float64   `json:"lng"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// Promotion represents a marketing banner shown on home.
type Promotion struct {
	ID            string     `json:"id"`
	Title         string     `json:"title"`
	Description   string     `json:"description"`
	Code          string     `json:"code"`
	ImageURL      *string    `json:"imageUrl,omitempty"`
	GradientStart string     `json:"gradientStart"`
	GradientEnd   string     `json:"gradientEnd"`
	ExpiresAt     *time.Time `json:"expiresAt,omitempty"`
	Priority      int        `json:"priority"`
}

// NewsItem highlights product updates on home.
type NewsItem struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Body        string    `json:"body"`
	Category    string    `json:"category"`
	Icon        string    `json:"icon"`
	PublishedAt time.Time `json:"publishedAt"`
}

// SavedPlaceRepository handles CRUD for saved places.
type SavedPlaceRepository interface {
	List(ctx context.Context, userID string) ([]*SavedPlace, error)
	Create(ctx context.Context, place *SavedPlace) error
	Delete(ctx context.Context, userID, id string) error
}

// PromotionRepository exposes marketing banners.
type PromotionRepository interface {
	ListActive(ctx context.Context) ([]*Promotion, error)
}

// NewsRepository returns newsfeed entries.
type NewsRepository interface {
	ListLatest(ctx context.Context, limit int) ([]*NewsItem, error)
}

// HomeService orchestrates rider home data.
type HomeService struct {
	wallets    WalletRepository
	saved      SavedPlaceRepository
	promotions PromotionRepository
	news       NewsRepository
}

// NewHomeService wires repositories for home content.
func NewHomeService(wallets WalletRepository, saved SavedPlaceRepository, promotions PromotionRepository, news NewsRepository) *HomeService {
	return &HomeService{
		wallets:    wallets,
		saved:      saved,
		promotions: promotions,
		news:       news,
	}
}

// Wallet fetches or initialises the rider wallet summary.
func (s *HomeService) Wallet(ctx context.Context, userID string) (*WalletSummary, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	return s.wallets.Get(ctx, userID)
}

// SavedPlaces lists saved places for the rider.
func (s *HomeService) SavedPlaces(ctx context.Context, userID string) ([]*SavedPlace, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	return s.saved.List(ctx, userID)
}

// CreateSavedPlace stores a new saved place.
func (s *HomeService) CreateSavedPlace(ctx context.Context, userID string, place *SavedPlace) (*SavedPlace, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	if place == nil {
		return nil, errors.New("place required")
	}
	place.UserID = userID
	now := time.Now().UTC()
	place.CreatedAt = now
	place.UpdatedAt = now
	if err := s.saved.Create(ctx, place); err != nil {
		return nil, err
	}
	return place, nil
}

// DeleteSavedPlace removes a saved place owned by the rider.
func (s *HomeService) DeleteSavedPlace(ctx context.Context, userID, id string) error {
	if userID == "" || id == "" {
		return errors.New("user id and saved place id required")
	}
	return s.saved.Delete(ctx, userID, id)
}

// Promotions lists active promotions, ordered by priority.
func (s *HomeService) Promotions(ctx context.Context) ([]*Promotion, error) {
	return s.promotions.ListActive(ctx)
}

// News lists the latest news items.
func (s *HomeService) News(ctx context.Context, limit int) ([]*NewsItem, error) {
	return s.news.ListLatest(ctx, limit)
}
