# UITGo – Kiến trúc hệ thống

## 1. Kiến trúc tổng quan

- Mô hình cloud-native/microservices gồm 3 service Go: `user-service`, `trip-service`, `driver-service` đứng sau API Gateway (Nginx). Mỗi service có Postgres riêng để tách schema và blast radius.
- Redis đảm nhiệm 3 vai trò: geospatial index cho driver search, cache (home feed), và hàng đợi ghép chuyến (Redis list/Streams, có biến `MATCH_QUEUE_*`).
- Quan sát & vận hành: Prometheus + Grafana (auto-provision dashboard), log JSON, Sentry hook cho backend/Flutter. Healthcheck và `/metrics` có mặt ở mọi service.
- Hạ tầng mẫu: Docker Compose cho dev/staging; Terraform scaffold ASG + RDS + Redis + SQS (dev) trong `infra/terraform`. Staging đơn giản chạy **một** ASG khởi động toàn bộ stack Compose (xem ADR-004).
- Bảo mật: JWT bắt buộc cho route bảo vệ, refresh token mã hóa/rotate, rate limit cho auth/trip create, header `X-Internal-Token` cho internal/debug.

```
                +-----------------+
                |  Flutter apps   |
                | (rider/driver)  |
                +---------+-------+
                          |
                     API Gateway
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

**Luồng chính**
- Request từ app → Gateway → route tới service tương ứng (REST + WebSocket).
- Mỗi service tự apply migration khi khởi động container.
- Observability sidecar (Prometheus scrape + Grafana dashboard) chạy cùng network Compose.

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
