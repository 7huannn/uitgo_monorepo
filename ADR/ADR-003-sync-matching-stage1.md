# ADR-003: Chọn mô hình ghép chuyến đồng bộ giai đoạn đầu (Stage 1)

- **Status:** Accepted (Stage 1), sẽ chuyển sang async queue khi tải tăng

## Context
- Ở giai đoạn đầu, số chuyến ít, đội nhỏ, ưu tiên ra tính năng nhanh và giảm độ phức tạp vận hành.
- trip-service cần tạo chuyến và trả driver nhanh mà không cần thêm thành phần mới (queue/worker) cho môi trường demo.
- Codebase đã tách microservice; việc thêm queue/consumer đòi hỏi thêm alerting và runbook.

## Options Considered
- **Đồng bộ:** trip-service gọi driver-service trực tiếp để chọn driver rồi trả về. Đơn giản, ít component, dễ debug.
- **Async queue (Redis/SQS):** enqueue event rồi worker driver-service xử lý. Chịu burst tốt, tách failure domain nhưng thêm độ phức tạp và eventual consistency.
- **Thuê ngoài (dịch vụ matching SaaS/managed):** không phù hợp phạm vi đồ án, chi phí và phụ thuộc cao.

## Decision
- Giữ **đồng bộ** cho Stage 1 (demo/đồ án), tối giản deployment. Tuy nhiên, chuẩn bị sẵn config `MATCH_QUEUE_*` và worker để có thể bật async khi cần (xem Module A load test).

## Consequences / Trade-offs
- **Ưu:** ít thành phần, thời gian triển khai ngắn; debugging đơn giản; không cần vận hành queue ngay từ đầu.
- **Nhược:** tail latency và tỷ lệ lỗi tăng khi burst (blocking trip-service); nếu driver-service chậm/outage sẽ làm request rider lỗi; thiếu khả năng hấp thụ backlog. Kết quả k6 cho thấy p95 ~820 ms khi đồng bộ, do đó cần chuyển sang async khi bước vào giai đoạn load cao.
