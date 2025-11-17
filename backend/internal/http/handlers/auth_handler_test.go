package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/domain"
)

func TestNewAuthHandlerValidation(t *testing.T) {
	t.Parallel()

	cfg := &config.Config{
		JWTSecret:       "",
		RefreshTokenKey: "",
		AccessTokenTTL:  time.Minute,
		RefreshTokenTTL: time.Hour,
	}
	handler, err := NewAuthHandler(cfg, newFakeUserRepo(), newFakeNotificationRepo(), &fakeDriverProvisioner{}, newFakeRefreshRepo())
	require.Error(t, err)
	require.Nil(t, handler)

	cfg.JWTSecret = "jwt"
	handler, err = NewAuthHandler(cfg, newFakeUserRepo(), newFakeNotificationRepo(), &fakeDriverProvisioner{}, newFakeRefreshRepo())
	require.Error(t, err)
	require.Nil(t, handler)
}

func TestAuthHandlerRegisterLoginRefresh(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	userRepo := newFakeUserRepo()
	notifs := newFakeNotificationRepo()
	refresh := newFakeRefreshRepo()
	handler, err := NewAuthHandler(&config.Config{
		JWTSecret:       "unit-test-secret",
		RefreshTokenKey: strings.Repeat("k", 32),
		AccessTokenTTL:  time.Minute,
		RefreshTokenTTL: time.Hour,
	}, userRepo, notifs, &fakeDriverProvisioner{}, refresh)
	require.NoError(t, err)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		if user := c.GetHeader("X-Test-User"); user != "" {
			c.Set("userID", user)
		}
		c.Next()
	})
	router.POST("/auth/register", handler.Register)
	router.POST("/auth/login", handler.Login)
	router.POST("/auth/refresh", handler.Refresh)
	router.GET("/auth/me", handler.Me)
	router.PATCH("/auth/me", handler.UpdateMe)

	registerPayload := `{"name":"UIT Rider","email":"rider@example.com","password":"secret123","phone":"0909000900"}`
	regResp := performJSONRequest(t, router, http.MethodPost, "/auth/register", registerPayload, http.StatusCreated, "")
	require.Equal(t, "rider@example.com", regResp["email"])
	require.NotEmpty(t, regResp["refreshToken"])
	require.NotEmpty(t, regResp["accessToken"])
	createdID := regResp["id"].(string)

	notifs.waitForSeed(t)

	loginPayload := `{"email":"rider@example.com","password":"secret123"}`
	loginResp := performJSONRequest(t, router, http.MethodPost, "/auth/login", loginPayload, http.StatusOK, "")
	require.Equal(t, createdID, loginResp["id"])
	require.NotEmpty(t, loginResp["refreshToken"])

	refreshPayload := `{"refreshToken":"` + loginResp["refreshToken"].(string) + `"}`
	refreshed := performJSONRequest(t, router, http.MethodPost, "/auth/refresh", refreshPayload, http.StatusOK, "")
	require.NotEqual(t, loginResp["refreshToken"], refreshed["refreshToken"])
	require.Equal(t, createdID, refreshed["id"])

	meResp := performJSONRequest(t, router, http.MethodGet, "/auth/me", "", http.StatusOK, createdID)
	require.Equal(t, "UIT Rider", meResp["name"])

	updatePayload := `{"name":"UIT Hero"}`
	updated := performJSONRequest(t, router, http.MethodPatch, "/auth/me", updatePayload, http.StatusOK, createdID)
	require.Equal(t, "UIT Hero", updated["name"])
	savedUser, err := userRepo.FindByID(context.Background(), createdID)
	require.NoError(t, err)
	require.Equal(t, "UIT Hero", savedUser.Name)
}

func TestAuthHandlerRegisterDriver(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	driverSvc := &fakeDriverProvisioner{}
	handler, err := NewAuthHandler(&config.Config{
		JWTSecret:       "driver-secret",
		RefreshTokenKey: strings.Repeat("s", 32),
		AccessTokenTTL:  time.Minute,
		RefreshTokenTTL: time.Hour,
	}, newFakeUserRepo(), newFakeNotificationRepo(), driverSvc, newFakeRefreshRepo())
	require.NoError(t, err)

	router := gin.New()
	router.POST("/drivers/register", handler.RegisterDriver)

	payload := `{"name":"UIT Driver","email":"driver@example.com","phone":"0909000999","password":"secret123","licenseNumber":"59X1-12345","vehicle":{"make":"Yamaha","model":"Grande","plateNumber":"59X1-12345"}}`
	resp := performJSONRequest(t, router, http.MethodPost, "/drivers/register", payload, http.StatusCreated, "")
	require.Equal(t, "driver@example.com", resp["email"])
	require.Equal(t, "driver", resp["role"])
	require.Equal(t, 1, driverSvc.calls())
}

func TestAuthHandlerErrors(t *testing.T) {
	t.Parallel()
	gin.SetMode(gin.TestMode)

	userRepo := newFakeUserRepo()
	refreshRepo := newFakeRefreshRepo()
	handler, err := NewAuthHandler(&config.Config{
		JWTSecret:       "another-secret",
		RefreshTokenKey: strings.Repeat("z", 32),
		AccessTokenTTL:  time.Minute,
		RefreshTokenTTL: time.Hour,
	}, userRepo, newFakeNotificationRepo(), &fakeDriverProvisioner{}, refreshRepo)
	require.NoError(t, err)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		if user := c.GetHeader("X-Test-User"); user != "" {
			c.Set("userID", user)
		}
	})
	router.POST("/auth/register", handler.Register)
	router.POST("/auth/login", handler.Login)
	router.POST("/auth/refresh", handler.Refresh)
	router.PATCH("/auth/me", handler.UpdateMe)

	// create baseline user
	payload := `{"name":"UIT Rider","email":"dup@example.com","password":"secret123"}`
	performJSONRequest(t, router, http.MethodPost, "/auth/register", payload, http.StatusCreated, "")

	// duplicate register
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/register", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusConflict, rec.Code)

	// login with wrong password
	badLogin := `{"email":"dup@example.com","password":"wrong"}`
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/auth/login", strings.NewReader(badLogin))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusUnauthorized, rec.Code)

	// update profile without context
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPatch, "/auth/me", strings.NewReader(`{"name":"Nope"}`))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusUnauthorized, rec.Code)

	// refresh using unknown token
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/auth/refresh", strings.NewReader(`{"refreshToken":"unknown"}`))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func performJSONRequest(t *testing.T, router http.Handler, method, path, payload string, expectedStatus int, userID string) map[string]any {
	t.Helper()
	rec := httptest.NewRecorder()
	var body io.Reader = http.NoBody
	if payload != "" {
		body = bytes.NewReader([]byte(payload))
	}
	req := httptest.NewRequest(method, path, body)
	if payload != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if userID != "" {
		req.Header.Set("X-Test-User", userID)
	}
	router.ServeHTTP(rec, req)
	require.Equal(t, expectedStatus, rec.Code, rec.Body.String())
	if rec.Body.Len() == 0 {
		return map[string]any{}
	}
	var decoded map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &decoded))
	return decoded
}

type fakeUserRepo struct {
	mu      sync.Mutex
	byEmail map[string]*domain.User
	byID    map[string]*domain.User
}

func newFakeUserRepo() *fakeUserRepo {
	return &fakeUserRepo{
		byEmail: make(map[string]*domain.User),
		byID:    make(map[string]*domain.User),
	}
}

func (r *fakeUserRepo) Create(_ context.Context, user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := strings.ToLower(user.Email)
	if _, exists := r.byEmail[key]; exists {
		return gorm.ErrDuplicatedKey
	}
	if user.ID == "" {
		user.ID = uuid.NewString()
	}
	user.CreatedAt = time.Now().UTC()
	copyUser := *user
	r.byEmail[key] = &copyUser
	r.byID[user.ID] = &copyUser
	return nil
}

func (r *fakeUserRepo) FindByEmail(_ context.Context, email string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if user, ok := r.byEmail[strings.ToLower(email)]; ok {
		copyUser := *user
		return &copyUser, nil
	}
	return nil, gorm.ErrRecordNotFound
}

func (r *fakeUserRepo) FindByID(_ context.Context, id string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if user, ok := r.byID[id]; ok {
		copyUser := *user
		return &copyUser, nil
	}
	return nil, gorm.ErrRecordNotFound
}

func (r *fakeUserRepo) UpdateProfile(ctx context.Context, id string, name *string, phone *string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	user, ok := r.byID[id]
	if !ok {
		return nil, gorm.ErrRecordNotFound
	}
	if name != nil && strings.TrimSpace(*name) != "" {
		user.Name = strings.TrimSpace(*name)
	}
	if phone != nil {
		trimmed := strings.TrimSpace(*phone)
		user.Phone = trimmed
	}
	copyUser := *user
	return &copyUser, nil
}

type fakeNotificationRepo struct {
	mu      sync.Mutex
	batches [][]*domain.Notification
	signal  chan struct{}
}

func newFakeNotificationRepo() *fakeNotificationRepo {
	return &fakeNotificationRepo{
		signal: make(chan struct{}, 1),
	}
}

func (r *fakeNotificationRepo) Create(ctx context.Context, notification *domain.Notification) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.batches = append(r.batches, []*domain.Notification{notification})
	return nil
}

func (r *fakeNotificationRepo) CreateMany(ctx context.Context, notifications []*domain.Notification) error {
	r.mu.Lock()
	r.batches = append(r.batches, notifications)
	r.mu.Unlock()
	select {
	case r.signal <- struct{}{}:
	default:
	}
	return nil
}

func (r *fakeNotificationRepo) List(_ context.Context, _ string, _ bool, _ int, _ int) ([]*domain.Notification, int64, error) {
	return nil, 0, errors.New("not implemented")
}

func (r *fakeNotificationRepo) MarkAsRead(_ context.Context, _, _ string) error {
	return errors.New("not implemented")
}

func (r *fakeNotificationRepo) waitForSeed(t *testing.T) {
	select {
	case <-r.signal:
	case <-time.After(2 * time.Second):
		t.Fatal("expected welcome notifications")
	}
}

type fakeDriverProvisioner struct {
	mu    sync.Mutex
	count int
	err   error
}

func (p *fakeDriverProvisioner) Register(_ context.Context, _ string, _ domain.DriverRegistrationInput) (*domain.Driver, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.count++
	if p.err != nil {
		return nil, p.err
	}
	return &domain.Driver{ID: uuid.NewString()}, nil
}

func (p *fakeDriverProvisioner) calls() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.count
}

type fakeRefreshRepo struct {
	mu      sync.Mutex
	records map[string]*domain.RefreshToken
	revoked map[string]bool
}

func newFakeRefreshRepo() *fakeRefreshRepo {
	return &fakeRefreshRepo{
		records: make(map[string]*domain.RefreshToken),
		revoked: make(map[string]bool),
	}
}

func (r *fakeRefreshRepo) Create(_ context.Context, token *domain.RefreshToken) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if token.ID == "" {
		token.ID = uuid.NewString()
	}
	copyToken := *token
	copyToken.TokenCiphertext = append([]byte{}, token.TokenCiphertext...)
	r.records[token.TokenHash] = &copyToken
	return nil
}

func (r *fakeRefreshRepo) FindActiveByHash(_ context.Context, hash string) (*domain.RefreshToken, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if token, ok := r.records[hash]; ok && !r.revoked[token.ID] && token.ExpiresAt.After(time.Now().Add(-time.Minute)) {
		copyToken := *token
		copyToken.TokenCiphertext = append([]byte{}, token.TokenCiphertext...)
		return &copyToken, nil
	}
	return nil, gorm.ErrRecordNotFound
}

func (r *fakeRefreshRepo) Revoke(_ context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.revoked[id] = true
	return nil
}

func (r *fakeRefreshRepo) RevokeAllForUser(_ context.Context, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for hash, token := range r.records {
		if token.UserID == userID {
			r.revoked[token.ID] = true
			delete(r.records, hash)
		}
	}
	return nil
}

var _ domain.UserRepository = (*fakeUserRepo)(nil)
var _ domain.NotificationRepository = (*fakeNotificationRepo)(nil)
var _ domain.RefreshTokenRepository = (*fakeRefreshRepo)(nil)
