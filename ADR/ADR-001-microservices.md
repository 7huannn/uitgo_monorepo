# ADR-001: Tách microservices thay vì monolith

- **Status:** Accepted

## Context
- Ban đầu hệ thống là monolith, nhưng chức năng rider/driver/admin, dòng dữ liệu trip, và auth phát triển nhanh, đòi hỏi scale và deploy riêng.
- Yêu cầu học phần: mô hình cloud-native, có API Gateway, có khả năng quan sát và tách domain.
- Đội muốn tách blast radius: lỗi driver-service không làm down auth, migration trip không khóa bảng user.

## Options Considered
- **Giữ monolith** (1 binary, 1 DB): đơn giản, ít chi phí vận hành, dễ debug nhưng scale đồng nhất, release chậm, rủi ro outage lan tỏa.
- **Monolith + module boundary** (package tách nhưng chung binary/DB): giảm một phần coupling, nhưng migration/scale vẫn chung tài nguyên, CI/CD không độc lập.
- **Microservices theo domain** (user/trip/driver + API Gateway + DB riêng): tách deployment, scale đúng hotspot, cô lập lỗi; cần thêm auth nội bộ, observability, và quản lý contract.

## Decision
- Chọn microservices theo domain: `user-service`, `trip-service`, `driver-service` sau API Gateway Nginx, mỗi service Postgres riêng, chia nhỏ CI/CD. Redis dùng chung cho GEO/queue/cache; Prometheus+Grafana+Sentry quan sát tập trung.

## Consequences / Trade-offs
- **Ưu:** deploy/rollback độc lập; scale trip-service hoặc driver-service theo load; lỗi 1 service không kéo sập toàn bộ; schema tách giảm nguy cơ deadlock/chặn migration.
- **Nhược:** tăng độ phức tạp (giao tiếp service-to-service, auth nội bộ `X-Internal-Token`); cần quản lý version API; nhiều pipeline build hơn; observability phải đầy đủ để debug phân tán.
