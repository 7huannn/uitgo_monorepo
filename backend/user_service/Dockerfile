# syntax=docker/dockerfile:1

FROM golang:1.22 AS builder
WORKDIR /workspace
COPY go.mod go.sum ./
COPY backend ./backend
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/workspace/backend/.cache/go-build,sharing=locked \
    cd backend && go build -o /workspace/bin/user-service ./user_service/cmd/server

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=builder /workspace/bin/user-service /app/user-service
COPY backend/user_service/migrations ./migrations
EXPOSE 8081
USER nonroot:nonroot
ENTRYPOINT ["/app/user-service"]
