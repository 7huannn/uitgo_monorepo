# Hướng dẫn Load Testing - UITGo# Hướng dẫn Load Testing - UITGo# Hướng dẫn Load Testing - UITGo# UIT-Go Load Testing Guide



## Yêu cầu cài đặt



- `k6` đã cài đặt ([hướng dẫn](https://k6.io/docs/getting-started/installation/))## Yêu cầu cài đặt

- Python 3 với `matplotlib` và `numpy`: `pip install matplotlib numpy`

- `make` có sẵn trong terminal

- Docker đang chạy backend: `docker compose up -d`

- `k6` đã cài đặt ([hướng dẫn](https://k6.io/docs/getting-started/installation/))## Yêu cầu cài đặt## Prerequisites

---

- Python 3 với `matplotlib` và `numpy`: `pip install matplotlib numpy`

## 🔐 Chuẩn bị tài khoản test

- `make` có sẵn trong terminal- `k6` installed locally.

### Bước 1: Đăng ký user mới (chỉ cần làm 1 lần)

- Docker đang chạy backend: `docker compose up -d`

```bash

curl -s -X POST http://localhost:8080/auth/register \- `k6` đã cài đặt ([hướng dẫn](https://k6.io/docs/getting-started/installation/))- Python 3 with `matplotlib` and `numpy` (`pip install matplotlib numpy`).

  -H "Content-Type: application/json" \

  -d '{"name":"Test Rider","email":"test.rider@example.com","password":"test123456","phone":"0900000001"}' | jq .---

```

- Python 3 với `matplotlib` và `numpy`: `pip install matplotlib numpy`- `make` available in your shell.

### Bước 2: Nạp tiền vào ví (bắt buộc để tạo trip)

## Chuẩn bị tài khoản test

```bash

TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \- `make` có sẵn trong terminal- Set a valid bearer token: `export ACCESS_TOKEN=<jwt>`.

  -H "Content-Type: application/json" \

  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')### Bước 1: Đăng ký user mới (chỉ cần làm 1 lần)



curl -s -X POST http://localhost:8080/v1/wallet/topup \- Docker đang chạy backend: `docker compose up -d`

  -H "Content-Type: application/json" \

  -H "Authorization: Bearer $TOKEN" \```bash

  -d '{"amount":2000000}' | jq .

```curl -s -X POST http://localhost:8080/auth/register \## One-command workflow



### Bước 3: Export token để sử dụng  -H "Content-Type: application/json" \



```bash  -d '{"name":"Test Rider","email":"test.rider@example.com","password":"test123456","phone":"0900000001"}' | jq .---```sh

export ACCESS_TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \

  -H "Content-Type: application/json" \```

  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')

ACCESS_TOKEN=... make loadtest-all

echo $ACCESS_TOKEN

```### Bước 2: Nạp tiền vào ví (bắt buộc để tạo trip)



### Bước 4: Lấy token mới khi hết hạn (token hết hạn sau 15 phút)## Lấy Access Token```



```bash```bash

export ACCESS_TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \

  -H "Content-Type: application/json" \# Lấy tokenWhat happens:

  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')

```TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \



---  -H "Content-Type: application/json" \### Bước 1: Đăng ký user mới (chỉ cần làm 1 lần)1. Runs `home_meta.js`, `search_only.js`, and `trip_matching.js` against localhost (`http://localhost:8080`).



## ⚠️ Lưu ý quan trọng về Rate Limit  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')



Hệ thống có **rate limit 10 requests/phút/user** cho endpoint tạo trip. Trong load test:2. Runs the same trio against staging AWS (`https://staging.api.uitgo.dev`).



- Script đã được cấu hình để accept rate limit (status 429) như expected behavior# Nạp 1,000,000 VND vào ví

- Metric `rate_limited_requests` cho biết số request bị limit

- Để test với RPS cao hơn, cần tạo nhiều user khác nhaucurl -s -X POST http://localhost:8080/v1/wallet/topup \```bash3. Aggregates results into tables and regenerates the latency-vs-RPS plot.



### Tạo nhiều user cho load test (optional)  -H "Content-Type: application/json" \



```bash  -H "Authorization: Bearer $TOKEN" \curl -s -X POST http://localhost:8080/auth/register \

chmod +x loadtests/scripts/setup_test_users.sh

NUM_USERS=20 ./loadtests/scripts/setup_test_users.sh  -d '{"amount":1000000}' | jq .

```

```  -H "Content-Type: application/json" \## Full Test Suite (Local only - no AWS needed)

---



## 🚀 Chạy Load Test

### Bước 3: Export token để sử dụng  -d '{"name":"Test Rider","email":"test.rider@example.com","password":"test123456","phone":"0900000001"}' | jq .```sh

### Chạy tất cả test (local, không cần AWS)



```bash

make loadtest-full-suite ACCESS_TOKEN=$ACCESS_TOKEN```bash```ACCESS_TOKEN=... make loadtest-full-suite

```

export ACCESS_TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \

### Chạy từng test riêng

  -H "Content-Type: application/json" \```

```bash

make loadtest-local ACCESS_TOKEN=$ACCESS_TOKEN  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')

make loadtest-trip-matching ACCESS_TOKEN=$ACCESS_TOKEN

```### Bước 2: Export token để sử dụngThis runs all tests including soak, stress, and spike tests locally.



---# Kiểm tra token



## 📋 Các kịch bản testecho $ACCESS_TOKEN



### 1. Soak Test - Phát hiện memory leak (10+ phút)```



```bash```bash## Individual Tests

make loadtest-soak ACCESS_TOKEN=$ACCESS_TOKEN

make loadtest-soak ACCESS_TOKEN=$ACCESS_TOKEN SOAK_DURATION=30m STEADY_VUS=20 RPS=30### Bước 4: Lấy token mới khi hết hạn (token hết hạn sau 15 phút)

```

# Lấy token và export

### 2. Stress Test - Tìm điểm giới hạn hệ thống

```bash

```bash

make loadtest-stress ACCESS_TOKEN=$ACCESS_TOKENexport ACCESS_TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \export ACCESS_TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \### Core Tests (existing)

make loadtest-stress ACCESS_TOKEN=$ACCESS_TOKEN MAX_RPS=200 STRESS_DURATION=1m

```  -H "Content-Type: application/json" \



### 3. Spike Test - Test đột biến traffic (5x, 10x)  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')  -H "Content-Type: application/json" \```sh



```bash```

make loadtest-spike ACCESS_TOKEN=$ACCESS_TOKEN

make loadtest-spike ACCESS_TOKEN=$ACCESS_TOKEN NORMAL_RPS=20 SPIKE_MULTIPLIER=5  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken')# Trip matching with ramping RPS

```

---

### 4. WebSocket Test - Độ trễ realtime

ACCESS_TOKEN=... make loadtest-trip-matching

```bash

make loadtest-websocket ACCESS_TOKEN=$ACCESS_TOKEN## Chạy Load Test

make loadtest-websocket ACCESS_TOKEN=$ACCESS_TOKEN WS_VUS=20 WS_DURATION=2m

```# Kiểm tra token



### 5. Driver Location Test - Hiệu năng Redis GEO### Chạy tất cả test (local, không cần AWS)



```bashecho $ACCESS_TOKEN# Home metadata endpoint

make loadtest-driver-location ACCESS_TOKEN=$ACCESS_TOKEN

make loadtest-driver-location ACCESS_TOKEN=$ACCESS_TOKEN NUM_DRIVERS=50```bash

```

make loadtest-full-suite ACCESS_TOKEN=$ACCESS_TOKEN```ACCESS_TOKEN=... make loadtest-local

---

```

## 📊 Kết quả đầu ra

```

| Loại | Đường dẫn | Mô tả |

|------|-----------|-------|### Chạy từng test riêng

| Kết quả JSON | `loadtests/results/*.json` | Dữ liệu chi tiết từ k6 |

| Bảng tổng hợp | `loadtests/report/summary.md` | Tóm tắt RPS, p95, error rate |### Bước 3: Lấy token mới khi hết hạn (token hết hạn sau 15 phút)

| Biểu đồ | `loadtests/plots/*.png` | Đồ thị latency, capacity |

```bash

### Tạo biểu đồ cho báo cáo

# Test luồng chính: tạo trip + tìm driver### Soak Test (10+ minutes, detect memory/connection leaks)

```bash

make loadtest-chartsmake loadtest-local ACCESS_TOKEN=$ACCESS_TOKEN

```

```bash```sh

---

# Test trip matching với nhiều mức RPS

## 📈 Tổng quan các kịch bản test

make loadtest-trip-matching ACCESS_TOKEN=$ACCESS_TOKENcurl -s -X POST http://localhost:8080/auth/login \ACCESS_TOKEN=... make loadtest-soak

| Test | Mục đích | Thời gian | Metrics chính |

|------|----------|-----------|---------------|```

| `trip_matching` | Hiệu năng luồng chính | 3.5 phút | p95 latency, throughput |

| `soak_test` | Phát hiện memory leak | 10-30 phút | Xu hướng latency |  -H "Content-Type: application/json" \# Optional: SOAK_DURATION=30m STEADY_VUS=20 RPS=30

| `stress_test` | Tìm breaking point | ~4 phút | Max RPS |

| `spike_test` | Xử lý traffic đột biến | ~3 phút | Recovery time |---

| `websocket_test` | Độ trễ realtime | 2 phút | Message latency |

| `driver_location_test` | Hiệu năng Redis GEO | 3 phút | Update latency |  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken'```



---## Các kịch bản test



## 🔍 Cách đọc kết quả```



### Các chỉ số quan trọng### 1. Soak Test - Phát hiện memory leak (10+ phút)



- **p95 < 250ms**: Đạt SLA mục tiêu### Stress Test (find breaking point)

- **Error rate < 1%**: Hệ thống ổn định (không tính rate limit)

- **rate_limited_requests**: Số request bị rate limit (expected trong load test)```bash



### Ví dụ outputmake loadtest-soak ACCESS_TOKEN=$ACCESS_TOKEN---```sh



```

checks_succeeded...: 100.00%

rate_limited_requests: 139 (expected với rate limit 10/min)# Tùy chỉnh:ACCESS_TOKEN=... make loadtest-stress

http_req_duration p(95): 7.03ms

```make loadtest-soak ACCESS_TOKEN=$ACCESS_TOKEN SOAK_DURATION=30m STEADY_VUS=20 RPS=30



---```## Chạy Load Test# Optional: MAX_RPS=200 STRESS_DURATION=1m



## ⚙️ Biến môi trường



| Biến | Mô tả | Mặc định |### 2. Stress Test - Tìm điểm giới hạn hệ thống```

|------|-------|----------|

| `ACCESS_TOKEN` | JWT token (bắt buộc) | - |

| `API_BASE` | URL của API | `http://localhost:8080` |

| `SOAK_DURATION` | Thời gian soak test | `10m` |```bash### Chạy tất cả test (local, không cần AWS)

| `MAX_RPS` | RPS tối đa stress test | `200` |

| `NORMAL_RPS` | RPS baseline spike test | `20` |make loadtest-stress ACCESS_TOKEN=$ACCESS_TOKEN

| `WS_VUS` | Số WebSocket connections | `20` |

| `NUM_DRIVERS` | Số driver giả lập | `50` |### Spike Test (burst traffic handling)


# Tùy chỉnh:

make loadtest-stress ACCESS_TOKEN=$ACCESS_TOKEN MAX_RPS=200 STRESS_DURATION=1m```bash```sh

```

make loadtest-full-suite ACCESS_TOKEN=$ACCESS_TOKENACCESS_TOKEN=... make loadtest-spike

### 3. Spike Test - Test đột biến traffic (5x, 10x)

```# Optional: NORMAL_RPS=20 SPIKE_MULTIPLIER=5

```bash

make loadtest-spike ACCESS_TOKEN=$ACCESS_TOKEN```



# Tùy chỉnh:### Chạy từng test riêng

make loadtest-spike ACCESS_TOKEN=$ACCESS_TOKEN NORMAL_RPS=20 SPIKE_MULTIPLIER=5

```### WebSocket Test (realtime latency)



### 4. WebSocket Test - Độ trễ realtime```bash```sh



```bash# Test luồng chính: tạo trip + tìm driverACCESS_TOKEN=... make loadtest-websocket

make loadtest-websocket ACCESS_TOKEN=$ACCESS_TOKEN

make loadtest-local ACCESS_TOKEN=$ACCESS_TOKEN# Optional: WS_VUS=20 WS_DURATION=2m

# Tùy chỉnh:

make loadtest-websocket ACCESS_TOKEN=$ACCESS_TOKEN WS_VUS=20 WS_DURATION=2m```

```

# Test trip matching với nhiều mức RPS

### 5. Driver Location Test - Hiệu năng Redis GEO

make loadtest-trip-matching ACCESS_TOKEN=$ACCESS_TOKEN### Driver Location Update Test (Redis GEO performance)

```bash

make loadtest-driver-location ACCESS_TOKEN=$ACCESS_TOKEN``````sh



# Tùy chỉnh:DRIVER_TOKEN=... make loadtest-driver-location

make loadtest-driver-location ACCESS_TOKEN=$ACCESS_TOKEN NUM_DRIVERS=50 UPDATE_INTERVAL=3 TEST_DURATION=3m

```---# Optional: NUM_DRIVERS=50 UPDATE_INTERVAL=3 TEST_DURATION=3m



---```



## Kết quả đầu ra## Các kịch bản test



### File được tạo## Generated artifacts



| Loại | Đường dẫn | Mô tả |### 1. Soak Test - Phát hiện memory leak (10+ phút)- k6 summaries: `loadtests/results/local_*.json`, `loadtests/results/aws_*.json`.

|------|-----------|-------|

| Kết quả JSON | `loadtests/results/*.json` | Dữ liệu chi tiết từ k6 |- Additional tests: `loadtests/results/{soak,stress,spike,websocket,driver_location}_test.json`

| Bảng tổng hợp | `loadtests/report/summary.md` | Tóm tắt RPS, p95, error rate |

| Biểu đồ | `loadtests/plots/rps_p95.png` | Đồ thị latency vs RPS |```bash- Aggregated tables: `loadtests/report/summary.csv`, `loadtests/report/summary.md`.



### Tạo biểu đồ cho báo cáomake loadtest-soak ACCESS_TOKEN=$ACCESS_TOKEN- Plot: `loadtests/plots/rps_p95.png` (local vs AWS series when data exists).



```bash

make loadtest-charts

```# Tùy chỉnh:## Environment variables



Sẽ tạo ra:make loadtest-soak ACCESS_TOKEN=$ACCESS_TOKEN SOAK_DURATION=30m STEADY_VUS=20 RPS=30- `ACCESS_TOKEN` (required): bearer token for authenticated endpoints.

- `baseline_vs_optimized.png` - So sánh trước/sau tối ưu

- `latency_distribution.png` - Phân bố latency theo percentile```- `DRIVER_TOKEN` (optional): bearer token for driver endpoints (falls back to ACCESS_TOKEN).

- `capacity_zones.png` - Vùng capacity của hệ thống

- `tradeoff_radar.png` - Biểu đồ radar trade-off kiến trúc- `LOCAL_API_BASE` (optional, default `http://localhost:8080`).



---### 2. Stress Test - Tìm điểm giới hạn hệ thống- `AWS_API_BASE` (optional, default `https://staging.api.uitgo.dev`).



## Tổng quan các kịch bản test- `RPS_STEPS` (optional, default `20 40 60 80 120`) to control trip-matching target RPS.



| Test | Mục đích | Thời gian | Metrics chính |```bash- `TARGET_RPS` is automatically set per run by the Makefile loop; manual overrides remain supported.

|------|----------|-----------|---------------|

| `trip_matching` | Hiệu năng luồng chính | 3.5 phút | p95 latency, throughput, error rate |make loadtest-stress ACCESS_TOKEN=$ACCESS_TOKEN

| `soak_test` | Phát hiện memory/connection leak | 10-30 phút | Xu hướng latency, lỗi tích lũy |

| `stress_test` | Tìm breaking point | ~4 phút | Max RPS trước khi lỗi, ngưỡng error |### Soak Test Variables

| `spike_test` | Xử lý traffic đột biến | ~3 phút | Thời gian recovery, queue absorption |

| `websocket_test` | Độ trễ realtime | 2 phút | Thời gian kết nối, độ trễ message |# Tùy chỉnh:- `SOAK_DURATION`: Test duration (default: 10m)

| `driver_location_test` | Hiệu năng Redis GEO | 3 phút | Độ trễ cập nhật, độ trễ geo query |

make loadtest-stress ACCESS_TOKEN=$ACCESS_TOKEN MAX_RPS=200 STRESS_DURATION=1m- `STEADY_VUS`: Number of virtual users (default: 10)

---

```- `RPS`: Requests per second (default: 20)

## Biến môi trường



### Biến chung

### 3. Spike Test - Test đột biến traffic (5x, 10x)### Stress Test Variables

| Biến | Mô tả | Mặc định |

|------|-------|----------|- `MAX_RPS`: Maximum RPS to reach (default: 200)

| `ACCESS_TOKEN` | JWT token để xác thực (bắt buộc) | - |

| `API_BASE` | URL của API | `http://localhost:8080` |```bash- `STRESS_DURATION`: Duration at peak stress (default: 30s)

| `RPS_STEPS` | Các mức RPS cho trip_matching | `20 40 60 80 120` |

make loadtest-spike ACCESS_TOKEN=$ACCESS_TOKEN

### Biến cho Soak Test

### Spike Test Variables

| Biến | Mô tả | Mặc định |

|------|-------|----------|# Tùy chỉnh:- `NORMAL_RPS`: Baseline RPS (default: 20)

| `SOAK_DURATION` | Thời gian chạy test | `10m` |

| `STEADY_VUS` | Số virtual users | `10` |make loadtest-spike ACCESS_TOKEN=$ACCESS_TOKEN NORMAL_RPS=20 SPIKE_MULTIPLIER=5- `SPIKE_MULTIPLIER`: Spike multiplier (default: 5, so 5x and 10x spikes)

| `RPS` | Requests per second | `20` |

```

### Biến cho Stress Test

### WebSocket Test Variables

| Biến | Mô tả | Mặc định |

|------|-------|----------|### 4. WebSocket Test - Độ trễ realtime- `WS_VUS`: Number of concurrent WebSocket connections (default: 20)

| `MAX_RPS` | RPS tối đa đạt được | `200` |

| `STRESS_DURATION` | Thời gian ở mức stress cao | `30s` |- `WS_DURATION`: Test duration (default: 2m)



### Biến cho Spike Test```bash



| Biến | Mô tả | Mặc định |make loadtest-websocket ACCESS_TOKEN=$ACCESS_TOKEN### Driver Location Test Variables

|------|-------|----------|

| `NORMAL_RPS` | RPS bình thường | `20` |- `NUM_DRIVERS`: Simulated drivers (default: 50)

| `SPIKE_MULTIPLIER` | Hệ số spike (5 = 5x và 10x) | `5` |

# Tùy chỉnh:- `UPDATE_INTERVAL`: Seconds between updates (default: 3)

### Biến cho WebSocket Test

make loadtest-websocket ACCESS_TOKEN=$ACCESS_TOKEN WS_VUS=20 WS_DURATION=2m- `TEST_DURATION`: Test duration (default: 3m)

| Biến | Mô tả | Mặc định |

|------|-------|----------|```

| `WS_VUS` | Số kết nối WebSocket đồng thời | `20` |

| `WS_DURATION` | Thời gian chạy test | `2m` |## Interpreting outputs



### Biến cho Driver Location Test### 5. Driver Location Test - Hiệu năng Redis GEO- `summary.md` / `summary.csv`: per-environment RPS targets, achieved RPS, p95 latency, and error rate. Use them to spot regressions or gaps between localhost and AWS.



| Biến | Mô tả | Mặc định |- `rps_p95.png`: visual p95 vs RPS, with separate series for LOCAL and AWS when data is present; synthetic curve only appears if no real data exists.

|------|-------|----------|

| `NUM_DRIVERS` | Số driver giả lập | `50` |```bash- Typical architectural checks: identify when p95 bends up (queueing), when error rate rises (back-pressure), and compare capacity headroom between local and AWS.

| `UPDATE_INTERVAL` | Giây giữa các lần cập nhật | `3` |

| `TEST_DURATION` | Thời gian chạy test | `3m` |make loadtest-driver-location ACCESS_TOKEN=$ACCESS_TOKEN



---## Test Scenarios Overview



## Cách đọc kết quả# Tùy chỉnh:



### Trong terminalmake loadtest-driver-location ACCESS_TOKEN=$ACCESS_TOKEN NUM_DRIVERS=50 UPDATE_INTERVAL=3 TEST_DURATION=3m| Test | Purpose | Duration | Key Metrics |



Sau khi chạy test, k6 sẽ hiển thị:```|------|---------|----------|-------------|

- **http_req_duration**: Thời gian response (p50, p90, p95, p99)

- **http_reqs**: Tổng số request và RPS đạt được| `trip_matching` | Core flow performance | 3.5m | p95 latency, throughput, error rate |

- **http_req_failed**: Tỷ lệ lỗi

---| `soak_test` | Memory/connection leaks | 10-30m | Latency trend, error accumulation |

### Trong file summary.md

| `stress_test` | Find breaking point | ~4m | Max RPS before failure, error threshold |

```

| environment | rps | p95_ms | achieved_rps | error_rate |## Kết quả đầu ra| `spike_test` | Burst handling | ~3m | Recovery time, queue absorption |

|-------------|-----|--------|--------------|------------|

| local       | 20  | 45.2   | 19.8         | 0.001      || `websocket_test` | Realtime latency | 2m | Connection time, message latency |

| local       | 40  | 82.5   | 39.5         | 0.002      |

```### File được tạo| `driver_location_test` | Redis GEO performance | 3m | Update latency, geo query latency |



### Các chỉ số cần quan tâm



- **p95 < 250ms**: Đạt SLA mục tiêu| Loại | Đường dẫn | Mô tả |

- **Error rate < 1%**: Hệ thống ổn định

- **Achieved RPS ≈ Target RPS**: Không bị nghẽn cổ chai|------|-----------|-------|Đăng ký user: 

| Kết quả JSON | `loadtests/results/*.json` | Dữ liệu chi tiết từ k6 |curl -s -X POST http://localhost:8080/auth/register \

---

| Bảng tổng hợp | `loadtests/report/summary.md` | Tóm tắt RPS, p95, error rate |  -H "Content-Type: application/json" \

## Lưu ý quan trọng

| Biểu đồ | `loadtests/plots/rps_p95.png` | Đồ thị latency vs RPS |  -d '{"name":"Test Rider","email":"test.rider@example.com","password":"test123456","phone":"0900000001"}' | jq .

1. **Token hết hạn sau 15 phút** - Chạy lại bước 4 để lấy token mới

2. **Cần nạp tiền vào ví** - Trip sẽ bị lỗi `insufficient wallet balance` nếu không có tiền

3. **Nạp đủ tiền cho test dài** - Mỗi trip tốn tiền, nên nạp nhiều (1-5 triệu VND) cho stress test

### Tạo biểu đồ cho báo cáo  export ACCESS_TOKEN= - sử dụng token

  make loadtest-local ACCESS_TOKEN=$ACCESS_TOKEN

```bash

make loadtest-charts  lấy token mới khi cần 

```  curl -s -X POST http://localhost:8080/auth/login \

  -H "Content-Type: application/json" \

Sẽ tạo ra:  -d '{"email":"test.rider@example.com","password":"test123456"}' | jq -r '.accessToken'
- `baseline_vs_optimized.png` - So sánh trước/sau tối ưu
- `latency_distribution.png` - Phân bố latency theo percentile
- `capacity_zones.png` - Vùng capacity của hệ thống
- `tradeoff_radar.png` - Biểu đồ radar trade-off kiến trúc

---

## Tổng quan các kịch bản test

| Test | Mục đích | Thời gian | Metrics chính |
|------|----------|-----------|---------------|
| `trip_matching` | Hiệu năng luồng chính | 3.5 phút | p95 latency, throughput, error rate |
| `soak_test` | Phát hiện memory/connection leak | 10-30 phút | Xu hướng latency, lỗi tích lũy |
| `stress_test` | Tìm breaking point | ~4 phút | Max RPS trước khi lỗi, ngưỡng error |
| `spike_test` | Xử lý traffic đột biến | ~3 phút | Thời gian recovery, queue absorption |
| `websocket_test` | Độ trễ realtime | 2 phút | Thời gian kết nối, độ trễ message |
| `driver_location_test` | Hiệu năng Redis GEO | 3 phút | Độ trễ cập nhật, độ trễ geo query |

---

## Biến môi trường

### Biến chung

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `ACCESS_TOKEN` | JWT token để xác thực (bắt buộc) | - |
| `API_BASE` | URL của API | `http://localhost:8080` |
| `RPS_STEPS` | Các mức RPS cho trip_matching | `20 40 60 80 120` |

### Biến cho Soak Test

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `SOAK_DURATION` | Thời gian chạy test | `10m` |
| `STEADY_VUS` | Số virtual users | `10` |
| `RPS` | Requests per second | `20` |

### Biến cho Stress Test

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `MAX_RPS` | RPS tối đa đạt được | `200` |
| `STRESS_DURATION` | Thời gian ở mức stress cao | `30s` |

### Biến cho Spike Test

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `NORMAL_RPS` | RPS bình thường | `20` |
| `SPIKE_MULTIPLIER` | Hệ số spike (5 = 5x và 10x) | `5` |

### Biến cho WebSocket Test

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `WS_VUS` | Số kết nối WebSocket đồng thời | `20` |
| `WS_DURATION` | Thời gian chạy test | `2m` |

### Biến cho Driver Location Test

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `NUM_DRIVERS` | Số driver giả lập | `50` |
| `UPDATE_INTERVAL` | Giây giữa các lần cập nhật | `3` |
| `TEST_DURATION` | Thời gian chạy test | `3m` |

---

## Cách đọc kết quả

### Trong terminal

Sau khi chạy test, k6 sẽ hiển thị:
- **http_req_duration**: Thời gian response (p50, p90, p95, p99)
- **http_reqs**: Tổng số request và RPS đạt được
- **http_req_failed**: Tỷ lệ lỗi

### Trong file summary.md

```
| environment | rps | p95_ms | achieved_rps | error_rate |
|-------------|-----|--------|--------------|------------|
| local       | 20  | 45.2   | 19.8         | 0.001      |
| local       | 40  | 82.5   | 39.5         | 0.002      |
```

### Các chỉ số cần quan tâm

- **p95 < 250ms**: Đạt SLA mục tiêu
- **Error rate < 1%**: Hệ thống ổn định
- **Achieved RPS ≈ Target RPS**: Không bị nghẽn cổ chai
