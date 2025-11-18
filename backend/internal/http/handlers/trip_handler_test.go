package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"

	"uitgo/backend/internal/domain"
)

func TestTripHandlerListTripsAndCreate(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	repo := newFakeTripRepo()
	wallet := &stubWalletOps{}
	service := domain.NewTripService(repo, wallet, nil)
	hubs := NewHubManager(service, nil)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		if user := c.GetHeader("X-Test-User"); user != "" {
			c.Set("userID", user)
		}
	})
	RegisterTripRoutes(router, service, nil, hubs, nil)

	userID := "rider-1"
	for i := 0; i < 3; i++ {
		trip := &domain.Trip{
			RiderID:    userID,
			ServiceID:  "uit-bike",
			OriginText: "Campus A",
			DestText:   "Dormitory",
		}
		require.NoError(t, service.Create(context.Background(), trip))
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/trips?page=2&pageSize=1", nil)
	req.Header.Set("X-Test-User", userID)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusOK, rec.Code)

	var list tripListResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &list))
	require.Equal(t, 1, list.Limit)
	require.Equal(t, 1, list.Offset)
	require.Equal(t, int64(3), list.Total)

	createPayload := `{"originText":"UIT","destText":"Dorm","serviceId":"uit-bike"}`
	res := performTripRequest(t, router, http.MethodPost, "/v1/trips", createPayload, userID)
	require.Equal(t, http.StatusCreated, res.Code)
	var created tripResponse
	require.NoError(t, json.Unmarshal(res.Body.Bytes(), &created))
	require.Equal(t, "UIT", created.OriginText)
	require.Equal(t, domain.TripStatusRequested, created.Status)
}

func TestTripHandlerCreateTripInsufficientFunds(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	repo := newFakeTripRepo()
	wallet := &stubWalletOps{ensureErr: domain.ErrWalletInsufficientFunds}
	service := domain.NewTripService(repo, wallet, nil)
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("userID", "wallet-user")
	})
	RegisterTripRoutes(router, service, nil, NewHubManager(service, nil), nil)

	res := performTripRequest(t, router, http.MethodPost, "/v1/trips", `{"originText":"A","destText":"B","serviceId":"bike"}`, "wallet-user")
	require.Equal(t, http.StatusPaymentRequired, res.Code)
}

func TestTripHandlerGetAndUpdateTrip(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	repo := newFakeTripRepo()
	service := domain.NewTripService(repo, nil, nil)
	hubs := NewHubManager(service, nil)
	router := gin.New()
	RegisterTripRoutes(router, service, nil, hubs, nil)

	trip := &domain.Trip{
		RiderID:    "rider-55",
		ServiceID:  "uit-bike",
		OriginText: "Campus",
		DestText:   "Dorm",
	}
	require.NoError(t, repo.CreateTrip(trip))
	location := &domain.LocationUpdate{Latitude: 10.1, Longitude: 106.2, Timestamp: time.Now().UTC()}
	repo.SaveLocation(trip.ID, *location)

	req := httptest.NewRequest(http.MethodGet, "/v1/trips/"+trip.ID, nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusOK, rec.Code)
	var fetched tripResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &fetched))
	require.Equal(t, trip.ID, fetched.ID)

	updatePayload := `{"status":"arriving"}`
	res := performTripRequest(t, router, http.MethodPatch, "/v1/trips/"+trip.ID+"/status", updatePayload, "")
	require.Equal(t, http.StatusOK, res.Code)
	var updated tripResponse
	require.NoError(t, json.Unmarshal(res.Body.Bytes(), &updated))
	require.Equal(t, domain.TripStatusArriving, updated.Status)
	require.NotNil(t, updated.LastLocation)
}

func TestTripHandlerGetTripNotFound(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	repo := newFakeTripRepo()
	service := domain.NewTripService(repo, nil, nil)
	router := gin.New()
	RegisterTripRoutes(router, service, nil, NewHubManager(service, nil), nil)

	req := httptest.NewRequest(http.MethodGet, "/v1/trips/"+uuidLike(), nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func performTripRequest(t *testing.T, router http.Handler, method, path, payload, userID string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, bytes.NewReader([]byte(payload)))
	req.Header.Set("Content-Type", "application/json")
	if userID != "" {
		req.Header.Set("X-Test-User", userID)
	}
	router.ServeHTTP(rec, req)
	return rec
}

type fakeTripRepo struct {
	mu        sync.Mutex
	trips     map[string]*domain.Trip
	order     []string
	locations map[string]*domain.LocationUpdate
}

func newFakeTripRepo() *fakeTripRepo {
	return &fakeTripRepo{
		trips:     make(map[string]*domain.Trip),
		order:     make([]string, 0),
		locations: make(map[string]*domain.LocationUpdate),
	}
}

func (r *fakeTripRepo) CreateTrip(trip *domain.Trip) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if trip.ID == "" {
		trip.ID = uuidLike()
	}
	now := time.Now().UTC()
	trip.CreatedAt = now
	trip.UpdatedAt = now
	trip.Status = domain.TripStatusRequested
	copyTrip := *trip
	if copyTrip.DriverID != nil {
		driver := *copyTrip.DriverID
		copyTrip.DriverID = &driver
	}
	r.trips[trip.ID] = &copyTrip
	r.order = append(r.order, trip.ID)
	return nil
}

func (r *fakeTripRepo) GetTrip(id string) (*domain.Trip, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if trip, ok := r.trips[id]; ok {
		c := *trip
		if c.DriverID != nil {
			driver := *c.DriverID
			c.DriverID = &driver
		}
		return &c, nil
	}
	return nil, domain.ErrTripNotFound
}

func (r *fakeTripRepo) UpdateTripStatus(id string, status domain.TripStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if trip, ok := r.trips[id]; ok {
		trip.Status = status
		trip.UpdatedAt = time.Now().UTC()
		return nil
	}
	return domain.ErrTripNotFound
}

func (r *fakeTripRepo) SetTripDriver(id string, driverID *string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if trip, ok := r.trips[id]; ok {
		if driverID != nil {
			driver := *driverID
			trip.DriverID = &driver
		} else {
			trip.DriverID = nil
		}
		return nil
	}
	return domain.ErrTripNotFound
}

func (r *fakeTripRepo) SaveLocation(tripID string, update domain.LocationUpdate) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.locations[tripID] = &domain.LocationUpdate{
		Latitude:  update.Latitude,
		Longitude: update.Longitude,
		Timestamp: update.Timestamp,
	}
	return nil
}

func (r *fakeTripRepo) GetLatestLocation(tripID string) (*domain.LocationUpdate, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if loc, ok := r.locations[tripID]; ok {
		copyLoc := *loc
		return &copyLoc, nil
	}
	return nil, nil
}

func (r *fakeTripRepo) ListTrips(userID, role string, limit, offset int) ([]*domain.Trip, int64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	filtered := make([]*domain.Trip, 0)
	for _, id := range r.order {
		trip := r.trips[id]
		switch role {
		case "driver":
			if trip.DriverID != nil && *trip.DriverID == userID {
				filtered = append(filtered, cloneTrip(trip))
			}
		default:
			if trip.RiderID == userID {
				filtered = append(filtered, cloneTrip(trip))
			}
		}
	}
	total := int64(len(filtered))
	if offset > len(filtered) {
		offset = len(filtered)
	}
	if limit <= 0 {
		limit = len(filtered)
	}
	end := offset + limit
	if end > len(filtered) {
		end = len(filtered)
	}
	return filtered[offset:end], total, nil
}

type stubWalletOps struct {
	ensureErr error
}

func (s *stubWalletOps) EnsureBalanceForTrip(ctx context.Context, userID, serviceID string) (int64, error) {
	if s.ensureErr != nil {
		return 0, s.ensureErr
	}
	return 15000, nil
}

func (s *stubWalletOps) DeductTripFare(ctx context.Context, userID, serviceID string) (*domain.WalletSummary, int64, error) {
	return nil, 0, nil
}

func (s *stubWalletOps) RewardTripCompletion(ctx context.Context, userID string) (*domain.WalletSummary, int64, error) {
	return nil, 0, nil
}

func cloneTrip(src *domain.Trip) *domain.Trip {
	copyTrip := *src
	if src.DriverID != nil {
		driver := *src.DriverID
		copyTrip.DriverID = &driver
	}
	return &copyTrip
}

func uuidLike() string {
	return time.Now().Format("20060102150405.000000")
}

var _ domain.TripRepository = (*fakeTripRepo)(nil)
