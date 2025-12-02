SHELL := /bin/bash
GO := GOROOT=/usr/local/go go
GOFLAGS :=

.PHONY: dev down run migrate test fmt tidy seed

dev:
	docker compose up --build

down:
	docker compose down

run:
	$(GO) run ./cmd/server

migrate:
	$(GO) run ./cmd/migrate

test:
	$(GO) test ./...

fmt:
	$(GO) fmt ./...

tidy:
	$(GO) mod tidy

seed:
	$(GO) run ./cmd/seed
