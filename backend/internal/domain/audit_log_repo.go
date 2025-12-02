package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AuditLog captures metadata about HTTP calls.
type AuditLog struct {
	ID         string
	UserID     string
	Method     string
	Path       string
	StatusCode int
	IPAddress  string
	UserAgent  string
	RequestID  string
	Outcome    string
	Error      string
	Latency    time.Duration
	CreatedAt  time.Time
}

// AuditLogRepository persists audit trail entries.
type AuditLogRepository interface {
	Create(ctx context.Context, log *AuditLog) error
}

// NewAuditLogRepository returns a GORM-backed audit logger.
func NewAuditLogRepository(db *gorm.DB) AuditLogRepository {
	return &gormAuditLogRepository{db: db}
}

type auditLogModel struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID     *string
	Method     string
	Path       string
	StatusCode int
	IPAddress  *string
	UserAgent  *string
	RequestID  *string
	Outcome    string
	Error      *string
	LatencyMS  int64 `gorm:"column:latency_ms"`
	CreatedAt  time.Time
}

func (auditLogModel) TableName() string {
	return "audit_logs"
}

type gormAuditLogRepository struct {
	db *gorm.DB
}

func (r *gormAuditLogRepository) Create(ctx context.Context, logEntry *AuditLog) error {
	model := auditLogModel{
		ID:         uuid.New(),
		Method:     logEntry.Method,
		Path:       logEntry.Path,
		StatusCode: logEntry.StatusCode,
		Outcome:    logEntry.Outcome,
		LatencyMS:  logEntry.Latency.Milliseconds(),
		CreatedAt:  time.Now().UTC(),
	}

	if logEntry.UserID != "" {
		userID := logEntry.UserID
		model.UserID = &userID
	}
	if logEntry.IPAddress != "" {
		ip := logEntry.IPAddress
		model.IPAddress = &ip
	}
	if logEntry.UserAgent != "" {
		ua := logEntry.UserAgent
		model.UserAgent = &ua
	}
	if logEntry.RequestID != "" {
		rid := logEntry.RequestID
		model.RequestID = &rid
	}
	if logEntry.Error != "" {
		errMsg := logEntry.Error
		model.Error = &errMsg
	}
	if logEntry.Latency > 0 {
		model.LatencyMS = logEntry.Latency.Milliseconds()
	}

	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return err
	}

	logEntry.ID = model.ID.String()
	logEntry.CreatedAt = model.CreatedAt
	return nil
}
