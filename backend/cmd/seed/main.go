package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"golang.org/x/crypto/bcrypt"

	"uitgo/backend/internal/config"
	"uitgo/backend/internal/db"
	"uitgo/backend/internal/domain"
)

func main() {
	ctx := context.Background()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	if cfg.DatabaseURL == "" {
		log.Fatal("POSTGRES_DSN not provided")
	}

	conn, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}

	userRepo := domain.NewUserRepository(conn)
	driverRepo := db.NewDriverRepository(conn)
	walletRepo := db.NewWalletRepository(conn)
	wallets := domain.NewWalletService(walletRepo)
	tripRepo := db.NewTripRepository(conn)

	log.Println("seeding demo users...")
	riders := []seedUser{
		{Name: "Nguyen Van An", Email: "rider.an@example.com", Phone: "0900000001", WalletBalance: 250000},
		{Name: "Tran Thi Binh", Email: "rider.binh@example.com", Phone: "0900000002", WalletBalance: 175000},
	}
	driverSeed := seedUser{Name: "Le Quang Driver", Email: "driver.le@example.com", Phone: "0900000099", Role: "driver", WalletBalance: 0}

	var riderProfiles []*domain.User
	for _, rider := range riders {
		user, err := ensureUser(ctx, userRepo, rider)
		if err != nil {
			log.Fatalf("ensure rider %s: %v", rider.Email, err)
		}
		if rider.WalletBalance > 0 {
			if _, err := wallets.TopUp(ctx, user.ID, rider.WalletBalance); err != nil {
				log.Fatalf("top up wallet for %s: %v", rider.Email, err)
			}
		}
		riderProfiles = append(riderProfiles, user)
		log.Printf(" - rider %s (%s)", user.Name, user.Email)
	}

	driverUser, err := ensureUser(ctx, userRepo, driverSeed)
	if err != nil {
		log.Fatalf("ensure driver user: %v", err)
	}
	driverProfile, err := createDriverProfile(ctx, driverRepo, driverUser, &domain.Vehicle{
		Make:        "Yamaha",
		Model:       "Grande",
		Color:       "Blue",
		PlateNumber: "59X1-12345",
	})
	if err != nil {
		log.Fatalf("create driver profile: %v", err)
	}
	log.Printf(" - driver %s ready for trips", driverProfile.FullName)

	log.Println("generating sample trips...")
	if err := seedTrips(ctx, tripRepo, riderProfiles, driverProfile); err != nil {
		log.Fatalf("seed trips: %v", err)
	}

	log.Println("demo data ready. Use the credentials above to log into the apps.")
}

type seedUser struct {
	Name          string
	Email         string
	Phone         string
	Role          string
	WalletBalance int64
}

func ensureUser(ctx context.Context, repo domain.UserRepository, input seedUser) (*domain.User, error) {
	existing, err := repo.FindByEmail(ctx, input.Email)
	if err == nil {
		return existing, nil
	}

	password := generatePassword(input.Email)
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	user := &domain.User{
		Name:         input.Name,
		Email:        input.Email,
		Phone:        input.Phone,
		Role:         input.Role,
		PasswordHash: string(hash),
	}
	if user.Role == "" {
		user.Role = "rider"
	}
	if err := repo.Create(ctx, user); err != nil {
		return nil, err
	}
	log.Printf("created %s (%s) password: %s", user.Role, user.Email, password)
	return user, nil
}

func createDriverProfile(ctx context.Context, repo domain.DriverRepository, user *domain.User, vehicle *domain.Vehicle) (*domain.Driver, error) {
	driver := &domain.Driver{
		UserID:        user.ID,
		FullName:      user.Name,
		Phone:         user.Phone,
		LicenseNumber: "UIT-" + user.ID[:8],
		Rating:        4.95,
	}
	if err := repo.Create(ctx, driver); err != nil {
		return nil, err
	}
	if vehicle != nil {
		vehicle.DriverID = driver.ID
		if _, err := repo.SaveVehicle(ctx, vehicle); err != nil {
			return nil, err
		}
	}
	if _, err := repo.SetAvailability(ctx, driver.ID, domain.DriverOnline); err != nil {
		return nil, err
	}
	return driver, nil
}

func seedTrips(ctx context.Context, repo domain.TripRepository, riders []*domain.User, driver *domain.Driver) error {
	now := time.Now().UTC()
	for idx, rider := range riders {
		for i, status := range []domain.TripStatus{
			domain.TripStatusRequested,
			domain.TripStatusArriving,
			domain.TripStatusCompleted,
		} {
			trip := &domain.Trip{
				RiderID:    rider.ID,
				ServiceID:  "uit-bike",
				OriginText: fmt.Sprintf("UIT Campus Gate %d", idx+1),
				DestText:   fmt.Sprintf("Dormitory Block %d", i+1),
				Status:     status,
				CreatedAt:  now.Add(-time.Duration(idx*i+1) * time.Hour),
				UpdatedAt:  now.Add(-time.Duration(idx*i+1) * time.Hour / 2),
			}
			if status != domain.TripStatusRequested {
				trip.DriverID = &driver.ID
			}
			if err := repo.CreateTrip(trip); err != nil {
				return err
			}
		}
	}
	return nil
}

func generatePassword(email string) string {
	if len(email) >= 6 {
		return email[:6] + "123"
	}
	return "uitgo123"
}
