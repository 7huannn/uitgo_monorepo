# UITGo – Kiến trúc hệ thống

## 1. Kiến trúc tổng quan

- Mô hình cloud-native/microservices gồm 3 service Go: `user-service`, `trip-service`, `driver-service` đứng sau API Gateway (Nginx/K8s Ingress). Mỗi service có Postgres riêng để tách schema và blast radius.
- Redis đảm nhiệm 3 vai trò: geospatial index cho driver search, cache (home feed), và hàng đợi ghép chuyến (Redis list/Streams, có biến `MATCH_QUEUE_*`).
- Quan sát & vận hành: Prometheus + Grafana + Loki (centralized logging), Sentry hook cho backend/Flutter. Healthcheck và `/metrics` có mặt ở mọi service.
- Hạ tầng:
  - **Local/Dev**: Docker Compose hoặc k3s Kubernetes
  - **Staging**: Kubernetes với Kustomize overlays, ArgoCD GitOps
  - **Cloud**: Terraform scaffold ASG + RDS + Redis + SQS
- Bảo mật: JWT bắt buộc cho route bảo vệ, refresh token mã hóa/rotate, rate limit cho auth/trip create, header `X-Internal-Token` cho internal/debug.

### 1.1 Kiến trúc Docker Compose (Development)
```
                +-----------------+
                |  Flutter apps   |
                | (rider/driver)  |
                +---------+-------+
                          |
                     API Gateway
                       (Nginx)
                          |
      +-------------------+-------------------+
      |                   |                   |
 user-service        trip-service        driver-service
  (8081)               (8082)                (8083)
      |                   |                   |
  Postgres           Postgres             Postgres
      +---------+     |   ^      +------------+
                |     |   |      |
                |   Redis (GEO / cache / queue)
                |     |   |      |
                +-----+---+------+
                      |
          Prometheus / Grafana / Sentry
```

### 1.2 Kiến trúc Kubernetes (Staging/Production)
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Kubernetes Cluster (k3s)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        argocd namespace                               │  │
│  │  ┌─────────────┐                                                      │  │
│  │  │   ArgoCD    │◀──── Watches Git repo ────▶ Auto-sync to cluster    │  │
│  │  │  (GitOps)   │                                                      │  │
│  │  └─────────────┘                                                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         uitgo namespace                               │  │
│  │                                                                        │  │
│  │        Ingress Controller (Traefik)                                   │  │
│  │              /auth/* │ /v1/trips/* │ /v1/drivers/*                    │  │
│  │                 │          │              │                           │  │
│  │                 ▼          ▼              ▼                           │  │
│  │  ┌──────────────────┬──────────────────┬──────────────────┐          │  │
│  │  │   user-service   │   trip-service   │  driver-service  │          │  │
│  │  │   Deployment     │   Deployment     │   Deployment     │          │  │
│  │  │   replicas: 1-2  │   replicas: 1-2  │   replicas: 1-2  │          │  │
│  │  └────────┬─────────┴────────┬─────────┴────────┬─────────┘          │  │
│  │           │                  │                  │                     │  │
│  │  ┌────────▼─────────┬────────▼─────────┬────────▼─────────┐          │  │
│  │  │   user-db        │   trip-db        │   driver-db      │          │  │
│  │  │  StatefulSet     │  StatefulSet     │  StatefulSet     │          │  │
│  │  │  PostgreSQL      │  PostgreSQL      │  PostgreSQL      │          │  │
│  │  └──────────────────┴──────────────────┴──────────────────┘          │  │
│  │                                                                        │  │
│  │                    ┌──────────────────┐                               │  │
│  │                    │      Redis       │                               │  │
│  │                    │   Deployment     │                               │  │
│  │                    │  GEO + Queue     │                               │  │
│  │                    └──────────────────┘                               │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      monitoring namespace                             │  │
│  │                                                                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │ Prometheus  │  │   Grafana   │  │    Loki     │  │  Promtail   │  │  │
│  │  │  (metrics)  │  │ (dashboards)│  │   (logs)    │  │ (DaemonSet) │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Luồng chính**
- Request từ app → Ingress → route tới service tương ứng (REST + WebSocket)
- Mỗi service tự apply migration khi khởi động container
- ArgoCD watch Git repository và auto-sync changes vào cluster
- Prometheus scrape `/metrics` từ tất cả services; logs ship qua Promtail → Loki

## 2. Kiến trúc module chuyên sâu: Trip Matching & Driver Search

### Mục tiêu
- Đảm bảo rider tạo chuyến nhanh, driver được phân công gần nhất, chịu được burst (vài trăm req/s) với độ trễ p95 <250 ms.

### Thành phần & vai trò
- **trip-service**: ghi nhận trip, xuất sự kiện ghép chuyến vào hàng đợi, stream trạng thái qua WebSocket.
- **driver-service**: lưu trạng thái driver, duy trì Redis GEO set `drivers:available`, worker/consumer lấy event ghép chuyến và tìm driver.
- **Redis**: GEO index (`GEOADD`/`GEORADIUS`) cho `/v1/drivers/search`; list/Streams cho hàng đợi ghép chuyến; key TTL cache home feed.
- **Postgres**: lưu trip + event (trip-service), driver profile + availability (driver-service); đảm bảo nguồn sự thật sau cùng.

### Luồng request (async matching – mặc định hiện tại)
1. Rider gọi `POST /v1/trips` qua Gateway.
2. trip-service ghi trip vào Postgres, đẩy sự kiện vào hàng đợi `MATCH_QUEUE_NAME` (Redis list/SQS tuỳ env).
3. Worker trong driver-service `BRPOP`/consume sự kiện, dùng Redis GEO để tìm driver gần nhất còn trống.
4. Worker khóa ngắn hạn (per-driver) để tránh double-assign, cập nhật trạng thái trip qua internal API + ghi audit.
5. trip-service đẩy cập nhật WebSocket tới rider/driver subscribers.

### Fallback đồng bộ (Stage 1)
- Khi không bật queue (hoặc trong môi trường tối giản), trip-service có thể gọi driver-service trực tiếp (synchronous) để chọn driver rồi trả về ngay. ADR-003 ghi lại lý do từng chọn phương án này ở giai đoạn đầu.

### Scaling & độ tin cậy
- **Compute**: Có thể scale số replica từng service (Compose `--scale` hoặc ASG tăng node). Worker matching tách process nên scale độc lập.
- **Data**: Redis chạy in-memory, không RDB snapshot trong dev/staging để đơn giản; Postgres tách schema giảm lock contention giữa domain.
- **Quan sát**: Queue depth, `match_worker_latency`, và `driver_search_p95` được scrape bởi Prometheus; dashboard sẵn trong `observability/grafana`.

### Liên hệ ADR
- ADR-001: tách microservice để độc lập triển khai/scale user/trip/driver.
- ADR-002: Redis GEO thay vì SQL thuần cho driver search.
- ADR-003: giữ mô hình đồng bộ ở Stage 1 để giảm độ phức tạp ban đầu, sau đó bật queue khi nhu cầu tăng.
- ADR-004: chọn Compose + ASG/Terraform cho staging thay vì EKS/ECS ở giai đoạn hiện tại.

## 3. CI/CD & GitOps Architecture

### 3.1 Pipeline Stages
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   STAGE 1   │    │   STAGE 2   │    │   STAGE 3   │    │   STAGE 4   │  │
│  │    TEST     │───▶│    BUILD    │───▶│  SECURITY   │───▶│   GITOPS    │  │
│  │             │    │             │    │             │    │             │  │
│  │ • go test   │    │ • docker    │    │ • Trivy     │    │ • kustomize │  │
│  │ • go vet    │    │   build     │    │   scan      │    │   edit      │  │
│  │ • lint      │    │ • push GHCR │    │ • SBOM gen  │    │ • git push  │  │
│  │ • coverage  │    │ • caching   │    │             │    │ • [skip ci] │  │
│  │   ≥80%      │    │             │    │             │    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 GitOps Workflow
```
Developer                    GitHub                      Kubernetes
    │                           │                            │
    │  git push                 │                            │
    ├──────────────────────────▶│                            │
    │                           │  trigger CI                │
    │                           ├────────┐                   │
    │                           │        │ test, build       │
    │                           │◀───────┘                   │
    │                           │                            │
    │                           │  update k8s/overlays/      │
    │                           │  kustomization.yaml        │
    │                           ├────────┐                   │
    │                           │        │ commit [skip ci]  │
    │                           │◀───────┘                   │
    │                           │                            │
    │                           │         ArgoCD watches     │
    │                           │◀───────────────────────────┤
    │                           │                            │
    │                           │         sync changes       │
    │                           ├───────────────────────────▶│
    │                           │                            │
    │                           │         health check       │
    │                           │◀───────────────────────────┤
    │                           │                            │
```

### 3.3 Kustomize Overlays Strategy

| Overlay | Branch | Replicas | Image Source | ArgoCD Sync |
|---------|--------|----------|--------------|-------------|
| `dev` | `dev` | 1 | localhost:5000 | Auto |
| `staging` | `main` | 2 | ghcr.io | Manual |

### 3.4 Observability Stack

| Component | Purpose | Data Flow |
|-----------|---------|-----------|
| **Prometheus** | Metrics collection | Scrape `/metrics` from all pods |
| **Grafana** | Visualization | Query Prometheus + Loki |
| **Loki** | Log aggregation | Receive logs from Promtail |
| **Promtail** | Log shipping | DaemonSet, ships container logs |

## 4. Cấu trúc Kubernetes Manifests

```
k8s/
├── base/                          # Base Kustomize resources
│   ├── namespace.yaml             # uitgo namespace
│   ├── configmap.yaml             # Shared config (service URLs, Redis addr)
│   ├── secrets.yaml               # Dev secrets (encrypt for prod!)
│   ├── databases.yaml             # 3× PostgreSQL StatefulSets
│   ├── redis.yaml                 # Redis Deployment
│   ├── user-service.yaml          # user-service Deployment + Service
│   ├── trip-service.yaml          # trip-service Deployment + Service
│   ├── driver-service.yaml        # driver-service Deployment + Service
│   ├── ingress.yaml               # Traefik Ingress rules
│   └── kustomization.yaml         # Base kustomization config
│
├── overlays/
│   ├── dev/                       # Development overrides
│   │   └── kustomization.yaml     # Local registry, 1 replica
│   └── staging/                   # Staging overrides
│       └── kustomization.yaml     # GHCR images, 2 replicas
│
├── monitoring/                    # Observability stack
│   ├── namespace.yaml
│   ├── prometheus.yaml            # Prometheus + RBAC
│   ├── grafana.yaml               # Grafana + datasources
│   ├── loki.yaml                  # Loki log aggregation
│   ├── promtail.yaml              # Promtail DaemonSet
│   └── kustomization.yaml
│
└── argocd/                        # GitOps applications
    ├── project.yaml               # ArgoCD project definition
    ├── uitgo-dev.yaml             # Dev application (auto-sync)
    └── uitgo-staging.yaml         # Staging application (manual sync)
```

## 5. Liên kết tài liệu

| Tài liệu | Mô tả |
|----------|-------|
| `docs/architecture-detailed.md` | Kiến trúc chi tiết Dev→Prod, CI/CD, GitOps, AWS staging (theo sơ đồ tổng thể) |
| `docs/DEVOPS_IMPLEMENTATION_SUMMARY.md` | Tổng quan DevOps và hướng dẫn sử dụng |
| `docs/architecture-stage1.md` | Skeleton microservice và biến môi trường |
| `docs/moduleA_scalability.md` | Báo cáo tối ưu hiệu năng và kết quả k6 |
| `ADR/*.md` | Architecture Decision Records |
| `backend/README.md` | Chi tiết API và hướng dẫn service Go |
