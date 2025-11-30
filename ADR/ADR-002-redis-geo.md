# ADR-002: Chọn Redis GEO cho driver search

- **Status:** Accepted

## Context
- Endpoint `/v1/drivers/search` cần trả về danh sách driver gần nhất theo tọa độ với độ trễ thấp. Traffic burst cao vào giờ cao điểm, đọc nhiều hơn ghi.
- Trong Compose và Terraform đã có Redis; driver-service đã duy trì tập `drivers:available`.

## Options Considered
- **Postgres geospatial (earthdistance/pgsphere):** tận dụng DB hiện có, mạnh về tính nhất quán; nhưng p95 cao khi hot region, tốn index maintain, khó scale read khi chỉ có 1 primary.
- **Redis GEO (GEOADD/GEORADIUS):** in-memory, latency thấp, sẵn có trong stack; cần cơ chế sync trạng thái và xử lý khi Redis down.
- **DynamoDB + Geo Library:** managed, scale tự động; nhưng thêm dịch vụ mới, latency phụ thuộc region, đội chưa có kinh nghiệm và Terraform module chưa sẵn.

## Decision
- Dùng **Redis GEO** làm lớp lookup chính cho driver search. Postgres lưu lịch sử/bản ghi authoritative, nhưng truy vấn realtime lấy từ GEO set `drivers:available`.

## Consequences / Trade-offs
- **Ưu:** p95 đọc giảm mạnh (từ ~380 ms xuống ~95 ms trong k6); tận dụng Redis đã có; dễ scale theo RAM; API đơn giản.
- **Nhược:** cần đồng bộ trạng thái driver vào GEO set (online/offline); dữ liệu in-memory nên phải chấp nhận khả năng mất cache sau reboot; cần fallback Postgres nếu Redis lỗi; phải dọn key & TTL cẩn thận để tránh stale driver.
