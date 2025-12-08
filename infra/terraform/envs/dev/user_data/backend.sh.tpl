#!/bin/bash
# cloud-init style bootstrap script for UITGo backend stack
set -xeuo pipefail

exec > >(tee -a /var/log/uitgo-user-data.log) 2>&1

install_docker() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    apt-get install -y docker.io docker-compose-plugin
  elif command -v yum >/dev/null 2>&1; then
    amazon-linux-extras enable docker || true
    yum update -y
    yum install -y docker
  elif command -v dnf >/dev/null 2>&1; then
    dnf update -y
    dnf install -y docker docker-compose-plugin
  else
    echo "No supported package manager found" >&2
    exit 1
  fi
}

install_docker

systemctl enable docker
systemctl start docker

mkdir -p /opt/uitgo

cat >/opt/uitgo/.env <<'EOF'
APP_ENV=production
AWS_REGION=${aws_region}
PORT=${backend_port}
JWT_SECRET=${jwt_secret}
REFRESH_TOKEN_ENCRYPTION_KEY=${refresh_token_key}
INTERNAL_API_KEY=${internal_api_key}
CORS_ALLOWED_ORIGINS=${cors_allowed_origins}
USER_DB_DSN=${user_db_dsn}
TRIP_DB_DSN=${trip_db_dsn}
TRIP_DB_REPLICA_DSN=${trip_db_replica_dsn}
DRIVER_DB_DSN=${driver_db_dsn}
REDIS_ADDR=${redis_addr}
REDIS_PASSWORD=${redis_password}
MATCH_QUEUE_REDIS_ADDR=${redis_addr}
MATCH_QUEUE_NAME=${match_queue_name}
MATCH_QUEUE_SQS_URL=${sqs_queue_url}
QUEUE_BACKEND=sqs
PROMETHEUS_ENABLED=true
EOF

cat >/opt/uitgo/docker-compose.yml <<'EOF'
version: "3.9"

services:
  user-service:
    image: ${user_service_image}
    restart: unless-stopped
    environment:
      PORT: 8081
      POSTGRES_DSN: $${USER_DB_DSN}
      JWT_SECRET: $${JWT_SECRET}
      REFRESH_TOKEN_ENCRYPTION_KEY: $${REFRESH_TOKEN_ENCRYPTION_KEY}
      CORS_ALLOWED_ORIGINS: $${CORS_ALLOWED_ORIGINS}
      INTERNAL_API_KEY: $${INTERNAL_API_KEY}
      DRIVER_SERVICE_URL: http://driver-service:8083
      TRIP_SERVICE_URL: http://trip-service:8082
      PROMETHEUS_ENABLED: $${PROMETHEUS_ENABLED}
      REDIS_ADDR: $${REDIS_ADDR}
      REDIS_PASSWORD: $${REDIS_PASSWORD}
    depends_on:
      - trip-service
      - driver-service

  trip-service:
    image: ${trip_service_image}
    restart: unless-stopped
    environment:
      PORT: 8082
      POSTGRES_DSN: $${TRIP_DB_DSN}
      TRIP_DB_REPLICA_DSN: $${TRIP_DB_REPLICA_DSN}
      JWT_SECRET: $${JWT_SECRET}
      REFRESH_TOKEN_ENCRYPTION_KEY: $${REFRESH_TOKEN_ENCRYPTION_KEY}
      INTERNAL_API_KEY: $${INTERNAL_API_KEY}
      DRIVER_SERVICE_URL: http://driver-service:8083
      MATCH_QUEUE_REDIS_ADDR: $${MATCH_QUEUE_REDIS_ADDR}
      MATCH_QUEUE_NAME: $${MATCH_QUEUE_NAME}
      MATCH_QUEUE_SQS_URL: $${MATCH_QUEUE_SQS_URL}
      QUEUE_BACKEND: $${QUEUE_BACKEND}
      PROMETHEUS_ENABLED: $${PROMETHEUS_ENABLED}
      REDIS_ADDR: $${REDIS_ADDR}
      REDIS_PASSWORD: $${REDIS_PASSWORD}

  driver-service:
    image: ${driver_service_image}
    restart: unless-stopped
    environment:
      PORT: 8083
      POSTGRES_DSN: $${DRIVER_DB_DSN}
      JWT_SECRET: $${JWT_SECRET}
      REFRESH_TOKEN_ENCRYPTION_KEY: $${REFRESH_TOKEN_ENCRYPTION_KEY}
      INTERNAL_API_KEY: $${INTERNAL_API_KEY}
      TRIP_SERVICE_URL: http://trip-service:8082
      REDIS_ADDR: $${REDIS_ADDR}
      REDIS_PASSWORD: $${REDIS_PASSWORD}
      MATCH_QUEUE_REDIS_ADDR: $${MATCH_QUEUE_REDIS_ADDR}
      MATCH_QUEUE_NAME: $${MATCH_QUEUE_NAME}
      MATCH_QUEUE_SQS_URL: $${MATCH_QUEUE_SQS_URL}
      QUEUE_BACKEND: $${QUEUE_BACKEND}
      PROMETHEUS_ENABLED: $${PROMETHEUS_ENABLED}

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

  location = /healthz {
    return 200 'ok';
  }

  location ^~ /auth {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /users {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }
  location ^~ /admin {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /wallet {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /saved_places {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /promotions {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /news {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /notifications {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location = /v1/drivers/register {
    proxy_pass http://user_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /v1/drivers {
    proxy_pass http://driver_service;
    include /etc/nginx/proxy_params;
  }

  location ~ ^/v1/trips/.+/(assign|accept|decline|status)$ {
    proxy_pass http://driver_service;
    include /etc/nginx/proxy_params;
  }

  location ~ ^/v1/trips/.+/ws$ {
    proxy_pass http://trip_service;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ^~ /routes {
    proxy_pass http://trip_service;
    include /etc/nginx/proxy_params;
  }

  location ^~ /v1/trips {
    proxy_pass http://trip_service;
    include /etc/nginx/proxy_params;
  }
}
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
ExecStart=/usr/bin/docker compose up -d --remove-orphans
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable uitgo.service
systemctl start uitgo.service
