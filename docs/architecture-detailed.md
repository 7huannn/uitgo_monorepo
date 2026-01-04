# UITGo – Kiến trúc chi tiết (theo sơ đồ tổng thể)

Mô tả kiến trúc và các luồng phát triển/triển khai/quan sát tương ứng sơ đồ tổng thể UITGo.

## 1. Chuỗi Dev → CI → CD → Staging
- Dev push `dev`/`main` lên GitHub.
- GitHub Actions (quality gate):
  - `go test ./...`, `go vet`, `golangci-lint`.
  - `docker build` từng service Go; cache layer.
  - `k6` kiểm thử tải nhanh.
  - Aikido Security + Trivy quét image (vuln, SBOM).
  - SonarQube Cloud gate (bug, coverage, maintainability).
- Qua gate:
  - Push image lên GHCR, cập nhật tag trong `k8s/overlays/*`.
  - Kustomize overlays xác định replica, ingress host, registry theo môi trường.
- GitOps:
  - Argo CD watch repo; auto-sync dev (k3s), staging có thể manual/auto theo cấu hình app.
  - Cluster kéo image GHCR, rollout và health-check.
- Provisioning:
  - Terraform dựng AWS staging: VPC + SG + subnets, RDS Postgres, ElastiCache Redis, SQS, Auto Scaling Group (ASG) với launch template + user-data cài Docker/docker-compose.
  - Mỗi node ASG pull image GHCR, chạy gateway + 3 service qua docker-compose, trỏ tới RDS/Redis/SQS nội VPC.

## 2. Môi trường Local / Dev (Compose hoặc k3s)
- Client: Flutter (Rider/Driver, iOS/Android/Web) gọi Traefik API Gateway.
- Backend (Go):
  - `user-service`, `trip-service`, `driver-service` (REST + WebSocket) chạy container riêng.
  - Postgres tách riêng cho từng service để giảm blast radius.
  - Redis: GEO index tìm driver, cache home feed, hàng đợi ghép chuyến.
- Triển khai:
  - Docker Compose mặc định; có thể dùng k3s + Argo CD để bám sát GitOps.
  - Image lấy từ build local hoặc GHCR (cấu hình trong `docker-compose.yml`).
- Telemetry:
  - Mọi service expose `/metrics` và log; Promtail đẩy log, Prometheus scrape metrics, Grafana hiển thị/alert; lỗi gửi Sentry (backend + Flutter).
- Luồng dữ liệu:
  - App → Traefik → service → Postgres/Redis.
  - Metrics/logs → Prometheus/Loki; lỗi → Sentry.

## 3. Quan sát & vận hành
- **Prometheus**: thu thập metrics của mọi service/pod.
- **Grafana**: dashboard và alert (latency, queue depth, lỗi 5xx).
- **Loki + Promtail**: tập trung log container, truy vấn theo service/instance.
- **Sentry**: nhận lỗi runtime (backend/Flutter) ở dev/staging.

## 4. AWS Staging (Terraform + ASG)
- **Network**: VPC, public/private subnets, SG cho app và DB.
- **Compute**: ASG (EC2) với launch template + user-data cài Docker; mỗi instance pull GHCR và chạy docker-compose gồm Nginx gateway + user-service + trip-service + driver-service.
- **Managed services**:
  - RDS Postgres riêng cho user/trip/driver.
  - ElastiCache Redis replication group (GEO/queue/cache).
  - SQS queue cho trip matching khi bật async worker.
- **Kết nối**:
  - Gateway/containers trong EC2 truy cập RDS/Redis/SQS nội VPC.
  - Promtail/metrics đẩy về stack observability; lỗi đẩy Sentry.

## 5. Ghi chú luồng (mapping sơ đồ)
- Đường liền: data/request/traffic thực tế từ client → gateway → services → DB/Redis.
- Đường nét đứt: control/deployment/telemetry (CI/CD, GitOps sync, metrics/logs, error tracking).
- GHCR là nguồn image chung cho k3s dev và ASG staging.
- `k8s/overlays/dev` và `k8s/overlays/staging` quyết định tag image, replica, ingress host; Argo CD chỉ đọc/đồng bộ các overlay này.

## 6. Phụ lục: chạy dự án & thông số
### 6.1 Dịch vụ & cổng
- `api-gateway` (Traefik/Nginx): 8080 – định tuyến tới backend.
- `user-service`: 8081 – auth, hồ sơ, ví, saved places, notifications. DB Postgres riêng.
- `trip-service`: 8082 – lifecycle chuyến đi, WebSocket update. DB Postgres riêng.
- `driver-service`: 8083 – onboarding, trạng thái, phân công chuyến. DB Postgres riêng.
- `redis`: 6379 – GEO index, cache, hàng đợi ghép chuyến (Redis list/Streams hoặc SQS khi bật).

### 6.2 Biến môi trường chính (áp dụng cho cả dev/staging)
- `PORT`: cổng service.
- `POSTGRES_DSN`: kết nối DB tương ứng (user/trip/driver).
- `JWT_SECRET`: ký/verify access token.
- `CORS_ALLOWED_ORIGINS`: danh sách origin Flutter web.
- `INTERNAL_API_KEY`: header `X-Internal-Token` cho internal API.
- `DRIVER_SERVICE_URL`, `TRIP_SERVICE_URL`: địa chỉ nội bộ cho calls chéo.
- `MATCH_QUEUE_NAME`: tên queue Redis (dev) nếu dùng async matching.
- `MATCH_QUEUE_SQS_URL`, `AWS_REGION`: cấu hình SQS (staging).

### 6.3 Local/dev nhanh
```bash
docker compose up --build   # chạy gateway + 3 service + Postgres + Redis + observability
docker compose down -v      # dọn
```
- API base: `http://localhost:8080`.
- Mỗi service tự chạy migration khi khởi động container.

### 6.4 GitOps/K8s (dev/staging)
- Base manifests: namespace, configmap, secrets, 3 Deployment + Service, 3 StatefulSet Postgres, Redis, Ingress.
- Overlays:
  - `dev`: 1 replica, registry local (localhost:5000), auto-sync Argo CD.
  - `staging`: 2 replica, image GHCR, manual sync Argo CD.
- Observability namespace: Prometheus, Grafana, Loki, Promtail; scrape `/metrics` của mọi pod.

### 6.5 Terraform (staging)
- Modules: network (VPC + subnets + SG), RDS (Postgres user/trip/driver), Redis (ElastiCache replication group), SQS queue + DLQ, ASG (EC2 + launch template cài docker-compose).
- Sau `terraform apply`: dùng output endpoint RDS/Redis/SQS để điền env cho compose/k8s.

### 6.6 Quan sát & vận hành
- Metrics: Prometheus; dashboards/alerts: Grafana.
- Logs: Promtail → Loki.
- Errors: Sentry (backend + Flutter).
- Chỉ số cần theo dõi: queue depth (Redis/SQS), `match_worker_latency`, `driver_search_p95`, lỗi 5xx trên gateway/service.
