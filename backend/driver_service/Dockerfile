# syntax=docker/dockerfile:1

FROM golang:1.25.3 AS builder
WORKDIR /workspace
COPY backend/go.mod backend/go.sum ./backend/
COPY backend ./backend
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/workspace/backend/.cache/go-build,sharing=locked \
    cd backend && go build -o /workspace/bin/driver-service ./driver_service/cmd/server

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=builder /workspace/bin/driver-service /app/driver-service
COPY backend/driver_service/migrations ./migrations
EXPOSE 8083
USER nonroot:nonroot
ENTRYPOINT ["/app/driver-service"]
