# UIT-Go Security & Observability Guide

This repository now ships hardened authentication flows, rate-limited public APIs, and end-to-end telemetry (Sentry, Prometheus, Grafana, and structured logs suitable for Loki/ELK).

## Quick start

```bash
# start Postgres, Go microservices, Prometheus, and Grafana
docker compose up --build
```

Available endpoints:

| Service     | URL                    |
| ----------- | ---------------------- |
| API Gateway | http://localhost:8080  |
| Prometheus  | http://localhost:9090  |
| Grafana     | http://localhost:3000  (admin / `uitgo`) |

Grafana auto-loads the dashboard defined in `observability/grafana/dashboards/uitgo-overview.json`.

## Configuration highlights

| Variable                       | Description                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `JWT_SECRET`                   | HMAC secret for access tokens (15‑minute expiry).                               |
| `REFRESH_TOKEN_ENCRYPTION_KEY` | Arbitrary string used to derive the AES‑GCM key for storing refresh tokens.     |
| `ACCESS_TOKEN_TTL_MINUTES`     | (Optional) Override access token lifetime (default 15).                         |
| `REFRESH_TOKEN_TTL_DAYS`       | (Optional) Override refresh token lifetime (default 30).                        |
| `SENTRY_DSN`                   | Backend DSN. Flutter apps read the DSN via `--dart-define SENTRY_DSN=...`.      |
| `PROMETHEUS_ENABLED`           | Toggle HTTP metrics middleware (enabled by default).                            |
| `CORS_ALLOWED_ORIGINS`         | Comma-separated list of approved origins (wildcards disabled).                  |
| `INTERNAL_API_KEY`             | Required for `/internal/*` debug endpoints.                                     |

Flutter apps accept:

- `API_BASE`
- `USE_MOCK`
- `SENTRY_DSN`

## Security updates

- `/auth/login`, `/auth/register`, and `/auth/refresh` now return `accessToken` (15 minutes) and `refreshToken` (30 days). Refresh tokens are encrypted and stored in the `refresh_tokens` table.
- `POST /auth/refresh` rotates the refresh token on every call and issues a fresh access token.
- `middleware.Auth` enforces JWT authentication for all protected routes (no more `demo-user` fallbacks). WebSocket clients must supply `Authorization: Bearer <token>` or an `accessToken` query parameter (Flutter web fallback).
- Login, registration, refresh, and trip creation endpoints are throttled (10 requests/minute/IP).
- Every request is stored in the `audit_logs` table (`userId`, path, status, error message, latency, request ID).
- CORS rejects unapproved origins instead of silently allowing `*`.

### Testing auth

```bash
# register
curl -s http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"UIT Rider","email":"rider@example.com","password":"passw0rd"}'

# login
LOGIN=$(curl -s http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"rider@example.com","password":"passw0rd"}')
ACCESS=$(echo "$LOGIN" | jq -r .accessToken)
REFRESH=$(echo "$LOGIN" | jq -r .refreshToken)

# current user
curl http://localhost:8080/auth/me -H "Authorization: Bearer $ACCESS"

# refresh
curl -s http://localhost:8080/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH\"}"
```

## Observability updates

- **Sentry** is wired into all Go binaries (`internal/observability/sentry.go`) and both Flutter apps (`sentry_flutter`). Trigger a test event with:

  ```bash
  curl -H "X-Internal-Token: $INTERNAL_API_KEY" http://localhost:8080/internal/debug/panic
  ```

- **Prometheus** scrapes `/metrics` from every Go service. Grafana auto-provisions a Prometheus datasource and the `UIT-Go Service Overview` dashboard (request rate, latency, and error rate panels).
- **Structured logging**: all Go services emit JSON to stdout (`middleware.JSONLogger` and `internal/logging`). These logs can be tailed by Promtail/Vector/Fluent Bit and forwarded to Loki/ELK.
- **Terraform** creates CloudWatch log groups for the API, user, driver, and trip services under `/uitgo/dev/*`, so ECS/EKS task definitions can attach the same structured stream. RDS networking is unchanged.

### Verifying metrics locally

```bash
# Prometheus targets
open http://localhost:9090/targets

# Grafana dashboard
open http://localhost:3000
```

## Flutter client notes

- Tokens live in `flutter_secure_storage`. The shared `DioClient` transparently refreshes access tokens when a request returns `401`.
- WebSocket connections attach the JWT (Authorization header on mobile/desktop, `accessToken` query parameter on web builds) so backend authorization always passes.
- Pass `--dart-define SENTRY_DSN=...` when running `flutter run` to enable Sentry in the mobile apps; errors automatically surface in the same project as the backend.

## Logging to Loki/ELK

Containers write JSON logs to stdout so you can ship them with your favourite collector. Example Promtail configuration:

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: uitgo
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    pipeline_stages:
      - json:
          expressions:
            level: level
            message: message
            service: service
```

Hook the output to Grafana Loki or any ELK cluster to keep a full audit trail.
