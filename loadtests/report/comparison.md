# AWS vs Local Load Test Comparison Report

*Generated: 2025-12-18 19:03:51*

---


## Home Meta

| Environment | RPS Target | RPS Achieved | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) | Error % | Total Req |
|-------------|------------|--------------|----------|----------|----------|----------|----------|---------|-----------|
| aws         |          0 |        39.75 |     0.00 |    12.43 |     0.00 |     2.62 |    30.93 |   0.000 |      2400 |
| local       |          0 |        39.73 |     0.00 |    12.26 |     0.00 |     2.50 |    43.13 |   0.000 |      2400 |

### Performance Comparison


**RPS N/A:**
- P95 Latency: AWS is +0.17ms (+1.4%) vs Local
- Error Rate: AWS 0.000% vs Local 0.000% (Δ +0.000%)
- Throughput: AWS achieved 39.7 RPS vs Local 39.7 RPS
  - ✅ **Good network performance**: Only 0ms overhead
  - ✅ **Stable error rates**: Infrastructure is reliable

## Search

| Environment | RPS Target | RPS Achieved | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) | Error % | Total Req |
|-------------|------------|--------------|----------|----------|----------|----------|----------|---------|-----------|
| aws         |          0 |        19.95 |     0.00 |     3.55 |     0.00 |     1.95 |     6.50 |   0.000 |      1200 |
| local       |          0 |        19.95 |     0.00 |     3.29 |     0.00 |     1.66 |    10.14 |   0.000 |      1200 |

### Performance Comparison


**RPS N/A:**
- P95 Latency: AWS is +0.26ms (+7.9%) vs Local
- Error Rate: AWS 0.000% vs Local 0.000% (Δ +0.000%)
- Throughput: AWS achieved 19.9 RPS vs Local 20.0 RPS
  - ✅ **Good network performance**: Only 0ms overhead
  - ✅ **Stable error rates**: Infrastructure is reliable

## Trip Matching

| Environment | RPS Target | RPS Achieved | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) | Error % | Total Req |
|-------------|------------|--------------|----------|----------|----------|----------|----------|---------|-----------|
| aws         |         10 |        16.54 |     0.00 |    68.64 |     0.00 |    54.49 |   211.80 |   0.000 |      4994 |
| aws         |         20 |        39.13 |     0.00 |     1.34 |     0.00 |     0.98 |     9.03 |   0.000 |      8218 |
| aws         |         40 |        55.32 |     0.00 |     1.42 |     0.00 |     0.96 |     7.53 |   0.000 |     11618 |
| aws         |         60 |        71.17 |     0.00 |     2.50 |     0.00 |     1.38 |    44.21 |   0.000 |     15018 |
| local       |         20 |        39.14 |     0.00 |     1.40 |     0.00 |     0.95 |    18.10 |   0.000 |      8219 |
| local       |         40 |        55.07 |     0.00 |     1.30 |     0.00 |     0.94 |     6.11 |   0.000 |     11620 |
| local       |         60 |        71.51 |     0.00 |     1.20 |     0.00 |     0.88 |    17.81 |   0.000 |     15018 |

### Performance Comparison


## Unknown

| Environment | RPS Target | RPS Achieved | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) | Error % | Total Req |
|-------------|------------|--------------|----------|----------|----------|----------|----------|---------|-----------|
| aws         |          0 |        16.54 |     0.00 |    68.64 |     0.00 |    54.49 |   211.80 |   0.000 |      4994 |
| local       |          0 |        49.80 |     0.00 |     2.61 |     0.00 |     1.62 |    94.10 |   0.000 |     89748 |
| local       |          0 |        36.46 |     0.00 |     2.61 |     0.00 |     1.65 |   188.21 |   0.000 |     24240 |
| unknown     |          0 |        49.97 |     0.00 |    60.74 |     0.00 |    52.68 |  1023.59 |   0.000 |    180002 |

### Performance Comparison


**RPS N/A:**
- P95 Latency: AWS is +66.02ms (+2525.8%) vs Local
- Error Rate: AWS 0.000% vs Local 0.000% (Δ +0.000%)
- Throughput: AWS achieved 16.5 RPS vs Local 49.8 RPS
  - ✅ **Stable error rates**: Infrastructure is reliable

---

## Summary

- **Local Average P95**: 3.53ms
- **Local Average Error Rate**: 0.000%
- **AWS Average P95**: 22.64ms
- **AWS Average Error Rate**: 0.000%
- **Network Overhead**: 19.12ms (542.2%)

## Recommendations

- ✅ **Excellent Performance**: System is production-ready
  - Consider testing at higher load levels
  - Run soak tests for stability validation

---

*For detailed metrics, see `summary.csv` and individual JSON files in `loadtests/results/`*
