# UITGo Monorepo

Nền tảng gọi xe gồm các Go microservice (user, trip, driver) sau API gateway, ứng dụng Flutter cho rider/driver, cùng stack quan sát (Prometheus, Grafana, Sentry) và bộ Terraform/hạ tầng mẫu. Kho repo này dành cho phát triển nội bộ, demo, và triển khai thử nghiệm.

## Toàn cảnh
- Backend: `user-service`, `trip-service`, `driver-service` chạy sau gateway Nginx; Redis dùng cho geospatial index và hàng đợi ghép chuyến.
- Ứng dụng: Flutter rider/driver (`apps/rider_app`, `apps/driver_app`) và admin prototype (`apps/admin_app`).
- Quan sát: Prometheus + Grafana auto-provisioned dashboard, Sentry hook cho backend và Flutter, log JSON sẵn sàng ship sang Loki/ELK.
- Hạ tầng: Docker Compose cho dev/staging, scaffold Terraform cho VPC, Postgres, Redis, SQS/ASG.

## Kiến trúc dịch vụ
| Service | Vai trò | Port | Lưu trữ |
| --- | --- | --- | --- |
| api-gateway | Định tuyến traffic từ ứng dụng | 8080 | — |
| user-service | Auth, hồ sơ, ví, địa điểm lưu, thông báo | 8081 | Postgres `user_service` |
| trip-service | Vòng đời chuyến, WebSocket trạng thái | 8082 | Postgres `trip_service` |
| driver-service | Onboarding, trạng thái tài xế, ghép chuyến | 8083 | Postgres `driver_service` |
| redis | GEO index + hàng đợi ghép chuyến | 6379 | In-memory |
| prometheus | Thu thập `/metrics` | 9090 | — |
| grafana | Dashboard quan sát | 3000 | — (admin/`uitgo`) |

## Yêu cầu hệ thống
- Docker + Docker Compose v2
- `make`
- Go 1.22+ (nếu chạy dịch vụ trực tiếp)
- Flutter stable (nếu build rider/driver)

## Khởi chạy nhanh
```bash
# từ thư mục gốc
docker compose up --build
```
- Khởi tạo 3 Postgres, 3 service Go, Redis, API Gateway, Prometheus, Grafana.
- Endpoint: API `http://localhost:8080`, Prometheus `http://localhost:9090`, Grafana `http://localhost:3000` (admin/`uitgo`).
- Grafana tự nạp dashboard `observability/grafana/dashboards/uitgo-overview.json`.

## Cấu hình chính
### Backend (biến dùng chung cho các service)
| Biến | Mô tả |
| --- | --- |
| `POSTGRES_DSN` | Chuỗi kết nối Postgres cho từng service. |
| `JWT_SECRET` | HMAC secret, access token mặc định 15 phút. |
| `REFRESH_TOKEN_ENCRYPTION_KEY` | Chuỗi dùng derive khoá AES-GCM lưu refresh token. |
| `ACCESS_TOKEN_TTL_MINUTES` | Tuỳ chọn override thời gian sống access token. |
| `REFRESH_TOKEN_TTL_DAYS` | Tuỳ chọn override refresh token (mặc định 30 ngày). |
| `CORS_ALLOWED_ORIGINS` | Danh sách origin cho phép, không dùng wildcard. |
| `INTERNAL_API_KEY` | Bắt buộc cho `/internal/*` và debug endpoint. |
| `SENTRY_DSN` | Bật Sentry cho backend. |
| `PROMETHEUS_ENABLED` | Bật/tắt middleware metrics. |
| `DRIVER_SERVICE_URL` / `TRIP_SERVICE_URL` | Service-to-service call. |
| `MATCH_QUEUE_REDIS_ADDR` / `MATCH_QUEUE_NAME` | Queue ghép chuyến async. |
| `REDIS_ADDR` | GEO index cho tìm kiếm tài xế. |

### Flutter
- `API_BASE` (mặc định `http://localhost:8080`)
- `USE_MOCK` (bật mock data nếu cần)
- `SENTRY_DSN`

## Phát triển backend
```bash
cd backend
make migrate   # chạy migration theo POSTGRES_DSN
make run       # khởi động server (PORT mặc định 8080)
make test      # unit test
make seed      # nạp rider, driver, ví, và chuyến mẫu
```
Các service khi chạy trong Docker tự apply migration. Seed in ra thông tin tài khoản demo để thử nhanh.

## Smoke test API (curl)
```bash
# đăng ký tài khoản mẫu
curl -s http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"UIT Rider","email":"rider@example.com","password":"passw0rd"}'

# đăng nhập
LOGIN=$(curl -s http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"rider@example.com","password":"passw0rd"}')
ACCESS=$(echo "$LOGIN" | jq -r .accessToken)
REFRESH=$(echo "$LOGIN" | jq -r .refreshToken)

# lấy thông tin hiện tại
curl http://localhost:8080/auth/me -H "Authorization: Bearer $ACCESS"

# refresh token
curl -s http://localhost:8080/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH\"}"
```

## Bảo mật & quan sát
- JWT 15 phút, refresh token 30 ngày (mã hoá, rotate mỗi lần refresh).
- Rate limit 10 request/phút cho login, register, refresh, tạo trip; CORS chỉ cho phép origin khai báo.
- Bắt buộc JWT cho tất cả route bảo vệ; WebSocket nhận `Authorization: Bearer` hoặc query `accessToken`.
- Request log vào bảng `audit_logs` (user, path, status, error, latency, request ID).
- Prometheus scrape `/metrics`; Grafana dashboard sẵn; log JSON sẵn sàng ship sang Loki/ELK.
- Sentry cho Go và Flutter; test panic: `curl -H "X-Internal-Token: $INTERNAL_API_KEY" http://localhost:8080/internal/debug/panic`.

## Kiểm thử & CI/CD
- Backend: `cd backend && make test` (`go test ./... -covermode=atomic` enforced trong CI).
- Flutter: `flutter analyze` và `flutter test` trong từng thư mục app.
- Load test: `k6 run loadtests/k6/trip_matching.js` (kịch bản rider/driver search).
- CI: `.github/workflows/be_ci.yml` (Go), `.github/workflows/fe_ci.yml` (Flutter), `.github/workflows/deploy.yml` build/push image `ghcr.io/.../uitgo-backend:<sha>`, build APK/IPA/Web, validate stack `infra/staging`.

## Triển khai & hạ tầng
- Staging Compose: `infra/staging` (copy `.env.staging.example` → `.env.staging`, rồi `docker compose up -d`).
- Terraform scaffold: `infra/terraform` (module network, rds, redis, sqs, asg). Đặt `TF_VAR_db_password` (hoặc file `dev.tfvars`) rồi `terraform init && terraform apply` trong `infra/terraform/envs/dev`.

## Tài liệu thêm
- `docs/architecture-stage1.md` – mô tả skeleton microservice và biến môi trường.
- `docs/moduleA_scalability.md` – báo cáo tối ưu hiệu năng và kết quả k6.
- `backend/README.md` – chi tiết API và hướng dẫn service Go.
