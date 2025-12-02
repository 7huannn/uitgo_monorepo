# UITGo – Báo cáo kiến trúc (Mục 5.1)

## 1. Tổng quan kiến trúc hệ thống
- Kiến trúc microservices: `user-service`, `trip-service`, `driver-service` phía sau API Gateway Nginx, mỗi service có Postgres riêng (cô lập schema và blast radius). Chi tiết luồng và sơ đồ trong `ARCHITECTURE.md`.
- Redis là thành phần chung: GEO index cho driver search, cache home feed TTL, và hàng đợi ghép chuyến (`MATCH_QUEUE_*`).
- Quan sát: Prometheus + Grafana auto-provision dashboard; log JSON sẵn cho ELK/Loki; Sentry cho backend/Flutter; healthcheck và `/metrics` trên mọi service.
- Hạ tầng staging: Docker Compose làm chuẩn cấu hình; Terraform scaffold tạo VPC, RDS, Redis, (tuỳ chọn SQS), và một Auto Scaling Group khởi động toàn bộ stack Compose (ADR-004). CI/CD build/push image, ASG kéo về.
- Bảo mật: JWT + refresh token mã hóa/rotate, rate-limit cho auth/trip, header `X-Internal-Token` cho internal/debug, CORS whitelist.

## 2. Phân tích module chuyên sâu – Trip Matching & Driver Search

### Cách tiếp cận
- Stage 1 ưu tiên đơn giản: trip-service gọi driver-service đồng bộ để chọn driver gần nhất (ADR-003). Phù hợp demo nhưng không chịu được burst.
- Stage hiện tại bật async matching: trip-service ghi trip → enqueue sự kiện vào Redis list/SQS; worker trong driver-service tiêu thụ, dùng Redis GEO để tìm driver gần nhất và cập nhật trạng thái trip qua internal API. WebSocket phát tới rider/driver.
- Data plane: Postgres lưu trip/events/driver profile; Redis giữ GEO set `drivers:available` và queue; fallback Postgres khi Redis gặp sự cố.

### Luồng chính (tóm tắt)
1. Rider `POST /v1/trips` → Gateway → trip-service.
2. trip-service persist trip + enqueue sự kiện ghép chuyến (`MATCH_QUEUE_NAME`).
3. Worker driver-service `BRPOP`/consume, chạy GEO lookup, khóa ngắn hạn driver, gọi internal API cập nhật trip & audit log.
4. trip-service đẩy cập nhật WebSocket tới rider/driver.

### Kết quả load test (k6 – `loadtests/k6/trip_matching.js`, số liệu `docs/moduleA_scalability.md`)
- Kịch bản: `riders` ramp tới 50 RPS tạo trip; `driverSearch` giữ 40 RPS gọi search. JWT seed để tránh auth bottleneck.
- **Baseline đồng bộ** (chưa bật queue, không cache home): throughput ổn định ~120 req/s, p95 tạo trip ~820 ms, lỗi tăng sau khi driver-service nghẽn.
- **Tối ưu (async queue + Redis GEO + cache home)**:
  - Trip create throughput ~420 req/s, lỗi <1%, p95 ~210 ms vì API trả sau khi enqueue.
  - Driver search p95 ~95 ms (từ ~380 ms).
  - CPU driver-service 2 vCPU giảm từ ~95% xuống ~55% sau khi scale worker/ASG min=3.
  - Queue backlog peak ~600 events, được drain <15 s.

### Bottleneck còn lại
- Eventual consistency: rider có thể đợi 1–10 s mới được gán driver khi backlog cao.
- Redis đơn điểm (dev/staging) – mất cache/queue khi restart, cần runbook warmup.

## 3. Quyết định thiết kế & trade-off (trích từ ADR)
- **ADR-001 (microservices):** tách user/trip/driver + gateway để deploy/scale độc lập, giảm blast radius; đổi lại tăng độ phức tạp giao tiếp và observability phân tán.
- **ADR-002 (Redis GEO):** chọn Redis cho driver search để đạt p95 ~95 ms, tận dụng Redis sẵn có; trade-off là cần đồng bộ trạng thái vào GEO set và chấp nhận in-memory/lossy.
- **ADR-003 (matching đồng bộ Stage 1):** giữ đồng bộ để ship nhanh; trade-off tail latency cao khi burst và coupling trip↔driver. Load test cho thấy cần chuyển sang async (đã bật trong code, cần ADR follow-up).
- **ADR-004 (Compose + ASG staging):** dùng Docker Compose + ASG Terraform để dựng nhanh môi trường; trade-off là không scale độc lập từng service, chưa HA đa-AZ, logging/secret còn đơn giản.

## 4. Thách thức & bài học
- **Consistency vs latency:** Async queue cải thiện p95 nhưng mang lại độ trễ gán driver và yêu cầu theo dõi backlog/lag.
- **Vận hành Redis đa vai trò:** GEO + cache + queue chia sẻ một instance; cần giám sát memory/eviction, tách DB logical và alert keyspace.
- **Observability load test:** Việc thêm metric queue depth, match worker latency giúp khoanh vùng bottleneck nhanh; k6 script và artifact JSON được lưu lại để so sánh regression.
- **Triển khai staging đơn giản:** Compose trên ASG giúp đưa môi trường lên nhanh, nhưng việc thiếu HA và per-service scaling là giới hạn rõ ràng khi chuẩn bị cho production.

## 5. Kết quả & hướng phát triển
- **Kết quả hiện tại:** Kiến trúc microservices ổn định cho dev/staging; async matching + Redis GEO đạt mục tiêu p95 <250 ms trong kịch bản tải đã kiểm thử; observability căn bản hoàn thiện.
- **Giới hạn:** Chưa có DLQ/retention cho queue; Redis đơn instance; Compose+ASG chưa HA; ADR cho async queue chưa được ghi chính thức.
- **Hướng phát triển (Stage tiếp theo):**
  - Ghi ADR follow-up cho async matching + SQS/DLQ, rollout chính thức.
  - Bổ sung alert backlog queue và retry/DLQ; tách Redis queue khỏi GEO/cache nếu dung lượng tăng.
  - Tận dụng RDS read replica cho endpoint đọc nặng; bổ sung circuit breaker cho call nội bộ.
  - Cân nhắc chuyển staging lên ECS/EKS khi cần scale độc lập từng service; chuẩn hóa secret management (SSM/Secrets Manager).
