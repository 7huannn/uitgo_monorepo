package handlers

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/domain"
)

// AuthHandler handles register/login flows.
type AuthHandler struct {
	users         domain.UserRepository
	jwtSecret     string
	notifications domain.NotificationRepository
	driverService DriverProvisioner
}

// DriverProvisioner provisions driver profiles during onboarding.
type DriverProvisioner interface {
	Register(ctx context.Context, userID string, input domain.DriverRegistrationInput) (*domain.Driver, error)
}

// NewAuthHandler builds an AuthHandler.
func NewAuthHandler(cfg *config.Config, users domain.UserRepository, notifications domain.NotificationRepository, driverService DriverProvisioner) *AuthHandler {
	return &AuthHandler{
		users:         users,
		jwtSecret:     cfg.JWTSecret,
		notifications: notifications,
		driverService: driverService,
	}
}

type registerRequest struct {
	Name     string `json:"name" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Phone    string `json:"phone"`
	Password string `json:"password" binding:"required,min=6"`
}

type loginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type authResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
	Role  string `json:"role,omitempty"`
	Token string `json:"token"`
}

type userResponse struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	Phone     string    `json:"phone,omitempty"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"createdAt"`
}

type updateProfileRequest struct {
	Name  *string `json:"name"`
	Phone *string `json:"phone"`
}

type registerDriverRequest struct {
	Name          string               `json:"name" binding:"required"`
	Email         string               `json:"email" binding:"required,email"`
	Phone         string               `json:"phone" binding:"required"`
	Password      string               `json:"password" binding:"required,min=6"`
	LicenseNumber string               `json:"licenseNumber" binding:"required"`
	Vehicle       *driverVehicleParams `json:"vehicle"`
}

type driverVehicleParams struct {
	Make        string `json:"make"`
	Model       string `json:"model"`
	Color       string `json:"color"`
	PlateNumber string `json:"plateNumber"`
}

func userIDFromContext(c *gin.Context) string {
	val, exists := c.Get("userID")
	if !exists {
		return ""
	}
	if id, ok := val.(string); ok {
		return id
	}
	return ""
}

func toUserResponse(user *domain.User) userResponse {
	return userResponse{
		ID:        user.ID,
		Name:      user.Name,
		Email:     user.Email,
		Phone:     user.Phone,
		Role:      user.Role,
		CreatedAt: user.CreatedAt,
	}
}

// Register signs up a new user.
func (h *AuthHandler) Register(c *gin.Context) {
	var req registerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Name = strings.TrimSpace(req.Name)
	req.Phone = strings.TrimSpace(req.Phone)

	if h.jwtSecret == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "jwt secret not configured"})
		return
	}

	if existing, err := h.users.FindByEmail(c.Request.Context(), req.Email); err == nil && existing != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
		return
	} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to check existing user"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to hash password"})
		return
	}

	user := &domain.User{
		Name:         req.Name,
		Email:        req.Email,
		Phone:        req.Phone,
		PasswordHash: string(hash),
		Role:         "rider",
	}

	if err := h.users.Create(c.Request.Context(), user); err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}

	go h.seedWelcomeNotifications(context.Background(), user.ID, user.Name)

	token, err := h.signToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to sign token"})
		return
	}

	c.JSON(http.StatusCreated, authResponse{
		ID:    user.ID,
		Email: user.Email,
		Name:  user.Name,
		Role:  user.Role,
		Token: token,
	})
}

// Login authenticates an existing user.
func (h *AuthHandler) Login(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	user, err := h.users.FindByEmail(c.Request.Context(), req.Email)
	if err != nil {
		status := http.StatusUnauthorized
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			status = http.StatusInternalServerError
		}
		c.JSON(status, gin.H{"error": "invalid credentials"})
		return
	}

	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := h.signToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to sign token"})
		return
	}

	c.JSON(http.StatusOK, authResponse{
		ID:    user.ID,
		Email: user.Email,
		Name:  user.Name,
		Role:  user.Role,
		Token: token,
	})
}

// Me returns the authenticated user.
func (h *AuthHandler) Me(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	user, err := h.users.FindByID(c.Request.Context(), userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load user"})
		return
	}

	c.JSON(http.StatusOK, toUserResponse(user))
}

// UpdateMe patches the authenticated user's profile.
func (h *AuthHandler) UpdateMe(c *gin.Context) {
	userID := userIDFromContext(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user context"})
		return
	}

	var req updateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Name == nil && req.Phone == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "nothing to update"})
		return
	}

	user, err := h.users.UpdateProfile(c.Request.Context(), userID, req.Name, req.Phone)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update profile"})
		return
	}

	c.JSON(http.StatusOK, toUserResponse(user))
}

// RegisterDriver creates a user plus driver profile.
func (h *AuthHandler) RegisterDriver(c *gin.Context) {
	if h.driverService == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "driver registration unavailable"})
		return
	}
	var req registerDriverRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Name = strings.TrimSpace(req.Name)
	req.Phone = strings.TrimSpace(req.Phone)

	if h.jwtSecret == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "jwt secret not configured"})
		return
	}

	if existing, err := h.users.FindByEmail(c.Request.Context(), req.Email); err == nil && existing != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
		return
	} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to check existing user"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to hash password"})
		return
	}

	user := &domain.User{
		Name:         req.Name,
		Email:        req.Email,
		Phone:        req.Phone,
		PasswordHash: string(hash),
		Role:         "driver",
	}
	if err := h.users.Create(c.Request.Context(), user); err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}

	driverInput := domain.DriverRegistrationInput{
		FullName:      req.Name,
		Phone:         req.Phone,
		LicenseNumber: req.LicenseNumber,
	}
	if req.Vehicle != nil {
		driverInput.Vehicle = &domain.Vehicle{
			Make:        req.Vehicle.Make,
			Model:       req.Vehicle.Model,
			Color:       req.Vehicle.Color,
			PlateNumber: req.Vehicle.PlateNumber,
		}
	}

	if _, err := h.driverService.Register(c.Request.Context(), user.ID, driverInput); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create driver profile"})
		return
	}

	token, err := h.signToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to sign token"})
		return
	}

	c.JSON(http.StatusCreated, authResponse{
		ID:    user.ID,
		Email: user.Email,
		Name:  user.Name,
		Role:  user.Role,
		Token: token,
	})
}

func (h *AuthHandler) signToken(user *domain.User) (string, error) {
	claims := jwt.MapClaims{
		"sub":   user.ID,
		"email": user.Email,
		"role":  user.Role,
		"iat":   time.Now().Unix(),
		"exp":   time.Now().Add(24 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.jwtSecret))
}

func (h *AuthHandler) seedWelcomeNotifications(ctx context.Context, userID, userName string) {
	if h.notifications == nil {
		return
	}

	displayName := strings.TrimSpace(userName)
	if displayName == "" {
		displayName = "UIT-Go Rider"
	}

	notifications := []*domain.Notification{
		{
			UserID: userID,
			Title:  "Chào mừng đến với UIT-Go!",
			Body:   "Xin chào " + displayName + ", cảm ơn bạn đã trải nghiệm UIT-Go. Chúng tôi đã sẵn sàng đồng hành trên mọi hành trình.",
			Type:   "system",
		},
		{
			UserID: userID,
			Title:  "Ưu đãi độc quyền",
			Body:   "Nhập mã UITGO50 để được giảm 50% cho chuyến đi đầu tiên trong hôm nay.",
			Type:   "promotion",
		},
	}

	if err := h.notifications.CreateMany(ctx, notifications); err != nil {
		log.Printf("seed welcome notifications: %v", err)
	}
}
