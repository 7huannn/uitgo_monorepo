package db

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"uitgo/backend/internal/domain"
)

type walletRepository struct {
	db *gorm.DB
}

var _ domain.WalletRepository = (*walletRepository)(nil)

// NewWalletRepository wires a GORM-backed wallet repository.
func NewWalletRepository(db *gorm.DB) domain.WalletRepository {
	return &walletRepository{db: db}
}

type walletModel struct {
	UserID       string `gorm:"primaryKey"`
	Balance      int64
	RewardPoints int64
	UpdatedAt    time.Time `gorm:"autoUpdateTime"`
}

func (walletModel) TableName() string {
	return "wallets"
}

type walletTransactionModel struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID    string    `gorm:"index"`
	Amount    int64
	Type      string
	CreatedAt time.Time `gorm:"autoCreateTime"`
}

func (walletTransactionModel) TableName() string {
	return "wallet_transactions"
}

func (r *walletRepository) Get(ctx context.Context, userID string) (*domain.WalletSummary, error) {
	if userID == "" {
		return nil, errors.New("user id required")
	}
	var model walletModel
	err := r.db.WithContext(ctx).First(&model, "user_id = ?", userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		model = walletModel{
			UserID:       userID,
			Balance:      0,
			RewardPoints: 0,
			UpdatedAt:    time.Now().UTC(),
		}
		if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}

	return &domain.WalletSummary{
		UserID:       model.UserID,
		Balance:      model.Balance,
		RewardPoints: model.RewardPoints,
		UpdatedAt:    model.UpdatedAt,
	}, nil
}

func (r *walletRepository) ListTransactions(ctx context.Context, userID string, limit, offset int) ([]*domain.WalletTransaction, int64, error) {
	if userID == "" {
		return nil, 0, errors.New("user id required")
	}
	query := r.db.WithContext(ctx).Model(&walletTransactionModel{}).Where("user_id = ?", userID)
	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var rows []walletTransactionModel
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return nil, 0, err
	}

	items := make([]*domain.WalletTransaction, 0, len(rows))
	for _, row := range rows {
		items = append(items, &domain.WalletTransaction{
			ID:        row.ID.String(),
			UserID:    row.UserID,
			Amount:    row.Amount,
			Type:      domain.WalletTransactionType(row.Type),
			CreatedAt: row.CreatedAt,
		})
	}
	return items, total, nil
}

func (r *walletRepository) ApplyTransaction(ctx context.Context, tx *domain.WalletTransaction) (*domain.WalletSummary, error) {
	if tx == nil {
		return nil, errors.New("transaction required")
	}
	if tx.UserID == "" {
		return nil, errors.New("user id required")
	}
	if tx.Amount < 0 {
		return nil, errors.New("amount must be non-negative")
	}

	var summary *domain.WalletSummary
	err := r.db.WithContext(ctx).Transaction(func(dbTx *gorm.DB) error {
		var wallet walletModel
		err := dbTx.Clauses(clause.Locking{Strength: "UPDATE"}).
			First(&wallet, "user_id = ?", tx.UserID).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			wallet = walletModel{
				UserID:       tx.UserID,
				Balance:      0,
				RewardPoints: 0,
				UpdatedAt:    time.Now().UTC(),
			}
			if err := dbTx.Create(&wallet).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}

		switch tx.Type {
		case domain.WalletTransactionTypeTopUp:
			wallet.Balance += tx.Amount
		case domain.WalletTransactionTypeDeduction:
			if wallet.Balance < tx.Amount {
				return domain.ErrWalletInsufficientFunds
			}
			wallet.Balance -= tx.Amount
		case domain.WalletTransactionTypeReward:
			wallet.RewardPoints += tx.Amount
		default:
			return domain.ErrWalletInvalidAmount
		}

		wallet.UpdatedAt = time.Now().UTC()
		if err := dbTx.Save(&wallet).Error; err != nil {
			return err
		}

		txn := walletTransactionModel{
			ID:     uuid.New(),
			UserID: tx.UserID,
			Amount: tx.Amount,
			Type:   string(tx.Type),
		}
		if !tx.CreatedAt.IsZero() {
			txn.CreatedAt = tx.CreatedAt
		}
		if err := dbTx.Create(&txn).Error; err != nil {
			return err
		}

		tx.ID = txn.ID.String()
		tx.CreatedAt = txn.CreatedAt
		summary = &domain.WalletSummary{
			UserID:       wallet.UserID,
			Balance:      wallet.Balance,
			RewardPoints: wallet.RewardPoints,
			UpdatedAt:    wallet.UpdatedAt,
		}
		return nil
	})

	return summary, err
}
