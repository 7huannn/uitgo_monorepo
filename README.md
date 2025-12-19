# UITGo Monorepo

UITGo là nền tảng gọi xe mẫu, trong đó ứng dụng Flutter cho rider và driver giao tiếp qua API Gateway tới các microservice viết bằng Go (user, trip, driver). Dự án tích hợp sẵn hệ thống quan sát (Prometheus, Grafana, Loki), GitOps với ArgoCD, và hạ tầng Kubernetes/Terraform, phục vụ phát triển, demo và triển khai thử nghiệm.

## Toàn cảnh
- **Backend**: `user-service`, `trip-service`, `driver-service` chạy sau gateway Nginx/Ingress; Redis dùng cho geospatial index và hàng đợi ghép chuyến.
- **Ứng dụng**: Flutter rider/driver (`apps/rider_app`, `apps/driver_app`) và admin prototype (`apps/admin_app`).
- **Quan sát**: Prometheus + Grafana + Loki (centralized logging), Sentry hook cho backend và Flutter.
- **Hạ tầng**: 
  - **Local/Dev**: Docker Compose hoặc k3s Kubernetes
  - **Staging**: Kubernetes với Kustomize overlays
  - **Cloud**: Terraform scaffold cho VPC, Postgres, Redis, SQS/ASG
- **GitOps**: ArgoCD tự động đồng bộ từ Git repository vào Kubernetes cluster.

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
- **Kubernetes local** (tùy chọn): k3s hoặc kind
- **Helm** (tùy chọn): để cài đặt monitoring stack

## Khởi chạy nhanh

### Option 1: Docker Compose (đơn giản nhất)
```bash
# từ thư mục gốc
docker compose up --build
```

### Option 2: Kubernetes với k3s (production-like)
```bash
# Chạy script setup tự động
./scripts/setup-local-devops.sh full

# Hoặc từng bước:
make k8s-build       # Build và push images
make k8s-deploy      # Deploy lên Kubernetes
make k8s-monitoring  # Deploy Prometheus + Grafana + Loki
make k8s-status      # Kiểm tra trạng thái
```

### Endpoints
| Service | Docker Compose | Kubernetes |
|---------|---------------|------------|
| API Gateway | http://localhost:8080 | http://uitgo.local |
| Prometheus | http://localhost:9090 | `make k8s-port-forward` |
| Grafana | http://localhost:3000 | `make k8s-port-forward` |
| ArgoCD | — | https://localhost:&lt;nodeport&gt; |

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
| `HOME_CACHE_TTL_SECONDS` | TTL cho Redis cache của `/promotions` & `/news` (mặc định 300s, đặt 0 để tắt). |
| `TRIP_DB_REPLICA_DSN` | (Tuỳ chọn) DSN read replica cho trip-service; nếu set các request đọc sẽ hit replica. |

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
- Load test: `make loadtest-trip-matching ACCESS_TOKEN=<jwt>` (sử dụng kịch bản rider/driver search, đặt `API_BASE` nếu không phải localhost; kết quả JSON nằm trong `loadtests/results/`).
- CI: `.github/workflows/be_ci.yml` (Go), `.github/workflows/fe_ci.yml` (Flutter), `.github/workflows/deploy.yml` build/push image `ghcr.io/.../uitgo-backend:<sha>`, build APK/IPA/Web, validate stack `infra/staging`.

### CI/CD Pipeline Stages
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    TEST     │───▶│    BUILD    │───▶│  SECURITY   │───▶│   GITOPS    │
│ • go test   │    │ • docker    │    │ • Trivy     │    │ • kustomize │
│ • lint      │    │   build     │    │   scan      │    │ • ArgoCD    │
│ • coverage  │    │ • push GHCR │    │ • SBOM      │    │   sync      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Chạy CI locally
```bash
make ci-local   # Sử dụng Act để chạy GitHub Actions trên máy local
```

## GitOps với ArgoCD
Dự án sử dụng GitOps pattern: thay đổi trong `k8s/overlays/` được ArgoCD tự động sync vào cluster.

```bash
# Xem trạng thái ArgoCD
make argocd-status

# Sync thủ công
make argocd-sync

# Workflow:
# 1. Push code → GitHub Actions chạy
# 2. CI build image mới → push GHCR
# 3. CI update image tag trong k8s/overlays/*/kustomization.yaml
# 4. ArgoCD phát hiện thay đổi → auto-sync vào K8s
```

## Triển khai & hạ tầng

### Kubernetes (Local/Staging)
```bash
# Cấu trúc Kubernetes manifests
k8s/
├── base/                 # Base configurations (Kustomize)
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── databases.yaml    # 3× PostgreSQL StatefulSets
│   ├── redis.yaml
│   ├── *-service.yaml    # user/trip/driver deployments
│   └── ingress.yaml
├── overlays/
│   ├── dev/              # Development overrides
│   └── staging/          # Staging overrides (more replicas)
├── monitoring/           # Prometheus + Grafana + Loki
└── argocd/               # GitOps application definitions

# Deploy commands
make k8s-deploy           # Deploy dev overlay
make k8s-deploy-staging   # Deploy staging overlay
make k8s-monitoring       # Deploy observability stack
make k8s-clean            # Cleanup all resources
```

### Docker Compose
- **Development**: `docker compose up --build` (root)
- **Staging**: `infra/staging` (copy `.env.staging.example` → `.env.staging`, rồi `docker compose up -d`)

### Terraform (Cloud)
- Scaffold & hướng dẫn: `infra/terraform/README.md`
- Modules: network, rds, redis, sqs, asg
- AWS triển khai dùng Auto Scaling Group chạy script `backend.sh.tpl` để khởi động toàn bộ stack Docker Compose.

## Security

### Aikido Security Integration (Active)
UITGo được bảo vệ bởi **Aikido Security** qua GitHub App integration - tự động scan mọi PR!

**Current Protection**:
-  **Dependencies**: Go modules + Flutter packages
-  **SAST**: Static code analysis
-  **Secrets**: Hardcoded credentials detection
-  **IaC**: Kubernetes & Terraform scanning
-  **Code Quality**: Best practices enforcement

**How It Works**:
- Every PR → Automatic security scan
- Findings posted as PR comments
- High/Critical issues → PR blocked
- Dashboard: https://app.aikido.dev/

**Full Guide**: [`docs/AIKIDO_SECURITY.md`](./docs/AIKIDO_SECURITY.md)  
**Current**: 1 critical, 4 high, 7 medium, 5 low issues

## Tài liệu thêm
- `docs/DEVOPS_IMPLEMENTATION_SUMMARY.md` – tổng quan hạ tầng DevOps và hướng dẫn sử dụng
- `docs/AIKIDO_SECURITY.md` – hướng dẫn sử dụng Aikido Security
- `docs/architecture-stage1.md` – mô tả skeleton microservice và biến môi trường
- `docs/moduleA_scalability.md` – báo cáo tối ưu hiệu năng và kết quả k6
- `backend/README.md` – chi tiết API và hướng dẫn service Go

## Makefile Commands

### Development
```bash
make dev          # Docker Compose up --build
make down         # Docker Compose down
```

### Kubernetes
```bash
make k8s-setup    # Setup full local K8s environment
make k8s-build    # Build & push images to local registry
make k8s-deploy   # Deploy to K8s (dev overlay)
make k8s-status   # Check cluster status
make k8s-logs-*   # View service logs (user/trip/driver)
make k8s-clean    # Cleanup all K8s resources
```

### CI/CD
```bash
make ci-local         # Run CI locally with Act
make argocd-sync      # Sync ArgoCD applications
make validate-manifests  # Validate K8s manifests
```

### Load Testing
```bash
make loadtest-local       # Run load tests locally
make loadtest-full-suite  # Complete load test suite
```
