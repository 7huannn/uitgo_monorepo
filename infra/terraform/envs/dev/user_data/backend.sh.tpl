#!/bin/bash
# UITGo backend bootstrap script for Amazon Linux 2023
set -euo pipefail

# SECURITY: Log to file only, avoid exposing secrets in console/IMDS
LOG_FILE=/var/log/uitgo-user-data.log
mkdir -p "$(dirname "$LOG_FILE")"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== UITGo bootstrap started at $(date -Is) ==="

# SECURITY: These values come from Terraform, avoid echoing them
BACKEND_PORT=${backend_port}
CONTAINER_REGISTRY=${container_registry}
REGISTRY_USERNAME=${registry_username}
REGISTRY_PASSWORD=${registry_password}
REDIS_PROXY_PORT=${redis_proxy_port}
REMOTE_REDIS_HOST=${redis_host}
REMOTE_REDIS_PORT=${redis_port}
REMOTE_REDIS_ADDR="${redis_host}:${redis_port}"

trap 'echo "[ERROR] User data failed at line $LINENO"' ERR

echo "[1/6] Installing Docker and dependencies..."
dnf update -y
dnf install -y docker jq socat ca-certificates
mkdir -p /usr/libexec/docker/cli-plugins
curl -fSL "https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-x86_64" \
  -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

echo "[2/6] Enabling Docker service..."
systemctl enable --now docker
usermod -aG docker ec2-user || true

REGISTRY_HOST="$${CONTAINER_REGISTRY%%/*}"
if [[ -n "$REGISTRY_USERNAME" && -n "$REGISTRY_PASSWORD" ]]; then
  echo "[2/6] Logging into container registry $${REGISTRY_HOST} as $${REGISTRY_USERNAME}..."
  echo "$REGISTRY_PASSWORD" | docker login "$${REGISTRY_HOST}" -u "$REGISTRY_USERNAME" --password-stdin
else
  echo "[2/6] Skipping registry login (no credentials provided). Ensure images are public."
fi

mkdir -p /opt/uitgo

echo "[3/6] Configuring Redis TLS tunnel on port $REDIS_PROXY_PORT -> $REMOTE_REDIS_ADDR..."
# SECURITY: Use proper TLS verification with ElastiCache
# ElastiCache uses Amazon-trusted certificates, verify=1 is safe
cat >/etc/systemd/system/redis-tunnel.service <<EOF
[Unit]
Description=TLS tunnel to ElastiCache Redis
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:${redis_proxy_port},reuseaddr,fork OPENSSL:${redis_host}:${redis_port},verify=1,cafile=/etc/ssl/certs/ca-certificates.crt
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now redis-tunnel.service
sleep 2

echo "[4/6] Writing configuration files..."
# SECURITY: Configuration written to file, not logged to console
cat >/opt/uitgo/docker-compose.yml <<'EOF'
version: "3.9"

services:
  user-service:
    image: ${user_service_image}
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      PORT: 8081
      POSTGRES_DSN: "${user_db_dsn}"
      JWT_SECRET: "${jwt_secret}"
      REFRESH_TOKEN_ENCRYPTION_KEY: "${refresh_token_key}"
      ACCESS_TOKEN_TTL_MINUTES: 120
      CORS_ALLOWED_ORIGINS: "${cors_allowed_origins}"
      INTERNAL_API_KEY: "${internal_api_key}"
      DRIVER_SERVICE_URL: "http://driver-service:8083"
      TRIP_SERVICE_URL: "http://trip-service:8082"
      PROMETHEUS_ENABLED: "true"
      REDIS_ADDR: "host.docker.internal:${redis_proxy_port}"
      REDIS_PASSWORD: "${redis_password}"
      AWS_REGION: "${aws_region}"
      APP_ENV: "production"

  trip-service:
    image: ${trip_service_image}
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      PORT: 8082
      POSTGRES_DSN: "${trip_db_dsn}"
      TRIP_DB_REPLICA_DSN: "${trip_db_replica_dsn}"
      JWT_SECRET: "${jwt_secret}"
      REFRESH_TOKEN_ENCRYPTION_KEY: "${refresh_token_key}"
      ACCESS_TOKEN_TTL_MINUTES: 120
      CORS_ALLOWED_ORIGINS: "${cors_allowed_origins}"
      INTERNAL_API_KEY: "${internal_api_key}"
      DRIVER_SERVICE_URL: "http://driver-service:8083"
      USER_SERVICE_URL: "http://user-service:8081"
      MATCH_QUEUE_NAME: "${match_queue_name}"
      MATCH_QUEUE_REDIS_ADDR: "host.docker.internal:${redis_proxy_port}"
      MATCH_QUEUE_REDIS_DB: 0
      QUEUE_BACKEND: "redis"
      PROMETHEUS_ENABLED: "true"
      REDIS_ADDR: "host.docker.internal:${redis_proxy_port}"
      REDIS_PASSWORD: "${redis_password}"
      APP_ENV: "production"
    depends_on:
      - driver-service

  driver-service:
    image: ${driver_service_image}
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      PORT: 8083
      POSTGRES_DSN: "${driver_db_dsn}"
      JWT_SECRET: "${jwt_secret}"
      REFRESH_TOKEN_ENCRYPTION_KEY: "${refresh_token_key}"
      ACCESS_TOKEN_TTL_MINUTES: 120
      CORS_ALLOWED_ORIGINS: "${cors_allowed_origins}"
      INTERNAL_API_KEY: "${internal_api_key}"
      TRIP_SERVICE_URL: "http://trip-service:8082"
      MATCH_QUEUE_NAME: "${match_queue_name}"
      MATCH_QUEUE_REDIS_ADDR: "host.docker.internal:${redis_proxy_port}"
      MATCH_QUEUE_REDIS_DB: 0
      QUEUE_BACKEND: "redis"
      PROMETHEUS_ENABLED: "true"
      REDIS_ADDR: "host.docker.internal:${redis_proxy_port}"
      REDIS_PASSWORD: "${redis_password}"
      APP_ENV: "production"

  api-gateway:
    image: nginx:1.25-alpine
    restart: unless-stopped
    depends_on:
      - user-service
      - trip-service
      - driver-service
    ports:
      - "${backend_port}:80"
    volumes:
      - /opt/uitgo/nginx.conf:/etc/nginx/conf.d/default.conf:ro
EOF

cat >/opt/uitgo/nginx.conf <<'EOF'
map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}

resolver 127.0.0.11 ipv6=off valid=30s;

# Allow listed web origins
map $http_origin $cors_origin {
  default "";
  ~^http://uitgo-(rider|driver)-web-demo-776751404852\.s3-website-ap-southeast-1\.amazonaws\.com$ $http_origin;
  ~^https://uitgo-(rider|driver)-web-demo-776751404852\.s3-website-ap-southeast-1\.amazonaws\.com$ $http_origin;
}

upstream user_service {
  server user-service:8081;
}

upstream trip_service {
  server trip-service:8082;
}

upstream driver_service {
  server driver-service:8083;
}

server {
  listen 80;
  server_name _;

  # CORS headers for all responses (gateway is the single place setting CORS)
  add_header Access-Control-Allow-Origin $cors_origin always;
  add_header Access-Control-Allow-Credentials true always;
  add_header Access-Control-Allow-Methods "GET,POST,PATCH,PUT,DELETE,OPTIONS" always;
  add_header Access-Control-Allow-Headers "Authorization,Content-Type,X-User-Id,X-Role,X-Request-Id" always;

  # Preflight short-circuit
  if ($request_method = OPTIONS) {
    return 204;
  }

  location = /health {
    default_type text/plain;
    return 200 'ok';
  }

  location ^~ /auth {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /users {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /admin {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /wallet {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /v1/wallet {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /saved_places {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /promotions {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /news {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /notifications {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location = /v1/drivers/register {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /v1/drivers {
    proxy_pass http://driver_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ~ ^/v1/trips/.+/(assign|accept|decline|status)$ {
    proxy_pass http://driver_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ~ ^/v1/trips/.+/ws$ {
    proxy_pass http://trip_service;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /routes {
    proxy_pass http://trip_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  # Internal maintenance endpoints (dev/demo only)
  location ^~ /internal/trips {
    proxy_pass http://trip_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /internal/trip-assignments {
    proxy_pass http://driver_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location /v1/trips {
    proxy_pass http://trip_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
EOF

cat >/opt/uitgo/proxy_params <<'EOF'
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Request-Id $http_x_request_id;
EOF

cat >/etc/systemd/system/uitgo.service <<'EOF'
[Unit]
Description=UITGo backend stack
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/uitgo
ExecStart=/bin/sh -c 'set -euo pipefail; echo "[uitgo.service] docker compose up" >&2; docker compose -f /opt/uitgo/docker-compose.yml up -d --remove-orphans || { echo "[uitgo.service] compose failed, dumping logs..." >&2; docker compose -f /opt/uitgo/docker-compose.yml logs --tail=200 || true; exit 1; }'
ExecStop=/bin/sh -c 'docker compose -f /opt/uitgo/docker-compose.yml down || true'
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

echo "[5/6] Starting containers..."
systemctl daemon-reload
systemctl enable uitgo.service
if ! systemctl start uitgo.service; then
  echo "[ERROR] uitgo.service failed to start, tailing logs..."
  journalctl -u uitgo.service --no-pager -n 200
  exit 1
fi

echo "[6/6] Waiting for API to become healthy on port ${backend_port}..."
for i in {1..30}; do
  if curl -fsS "http://localhost:${backend_port}/health" >/dev/null 2>&1; then
    echo "Service is healthy!"
    break
  fi
  echo "Waiting for service... ($i/30)"
  sleep 5
done

echo "Docker status:"
docker ps
echo "--- user-service logs (last 50 lines) ---"
docker logs --tail=50 uitgo-user-service-1 || true
echo "--- trip-service logs (last 50 lines) ---"
docker logs --tail=50 uitgo-trip-service-1 || true
echo "--- driver-service logs (last 50 lines) ---"
docker logs --tail=50 uitgo-driver-service-1 || true

echo "=== UITGo bootstrap completed at $(date -Is) ==="
