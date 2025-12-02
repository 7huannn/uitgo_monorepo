# syntax=docker/dockerfile:1

FROM golang:1.25.3 AS builder
WORKDIR /workspace
COPY backend/go.mod backend/go.sum ./backend/
COPY backend ./backend
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/workspace/backend/.cache/go-build,sharing=locked \
    cd backend && go build -o /workspace/bin/trip-service ./trip_service/cmd/server

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=builder /workspace/bin/trip-service /app/trip-service
COPY backend/trip_service/migrations ./migrations
EXPOSE 8082
USER nonroot:nonroot
ENTRYPOINT ["/app/trip-service"]
