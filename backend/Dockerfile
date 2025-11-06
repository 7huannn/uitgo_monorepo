# ---------- builder ----------
FROM golang:1.25.3-alpine AS builder

# (tùy chọn) nếu cần private repos: RUN apk add --no-cache git
WORKDIR /app

# Copy module files trước để cache go mod
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build binaries (static, nhỏ gọn)
ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -ldflags="-s -w" -o bin/server ./cmd/server && \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -ldflags="-s -w" -o bin/migrate ./cmd/migrate

# ---------- runtime ----------
FROM alpine:3.20

# Certificates & timezone để HTTPS/GORM TLS hoạt động chuẩn
RUN apk add --no-cache ca-certificates tzdata && update-ca-certificates

WORKDIR /app

# User không phải root
RUN adduser -D -g '' appuser

# Copy binaries + migrations
COPY --from=builder /app/bin/server /app/server
COPY --from=builder /app/bin/migrate /app/migrate
COPY --from=builder /app/migrations /app/migrations

USER appuser

# Env mặc định (chỉnh theo app của bạn)
ENV PORT=8080
# ENV GIN_MODE=release  # bật nếu app dùng gin

EXPOSE 8080

ENTRYPOINT ["/app/server"]
