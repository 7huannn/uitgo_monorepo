/**
 * Soak Test - Chạy dài hạn để phát hiện memory leak, connection leak
 * 
 * Mục đích:
 * - Phát hiện resource leak (memory, connections, file descriptors)
 * - Kiểm tra hệ thống hoạt động ổn định trong thời gian dài
 * - Phát hiện performance degradation theo thời gian
 * 
 * Cách chạy:
 *   ACCESS_TOKEN=... k6 run --summary-export loadtests/results/soak_test.json loadtests/k6/soak_test.js
 * 
 * Thời gian: 10-30 phút (có thể điều chỉnh SOAK_DURATION)
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics để track degradation theo thời gian
const tripLatency = new Trend('trip_create_latency', true);
const searchLatency = new Trend('driver_search_latency', true);
const errorRate = new Rate('error_rate');
const successfulTrips = new Counter('successful_trips');

// Cấu hình có thể override qua biến môi trường
const SOAK_DURATION = __ENV.SOAK_DURATION || '10m';
const STEADY_VUS = Number(__ENV.STEADY_VUS) || 10;
const RPS = Number(__ENV.RPS) || 20;

export const options = {
  scenarios: {
    soak_trips: {
      executor: 'constant-arrival-rate',
      rate: RPS,
      timeUnit: '1s',
      duration: SOAK_DURATION,
      preAllocatedVUs: STEADY_VUS,
      maxVUs: STEADY_VUS * 3,
    },
  },
  thresholds: {
    // Latency không được tăng quá 50% so với baseline
    'trip_create_latency': ['p(95)<500', 'avg<200'],
    'driver_search_latency': ['p(95)<200', 'avg<100'],
    // Error rate phải dưới 1% trong suốt thời gian test
    'error_rate': ['rate<0.01'],
    // HTTP duration overall
    'http_req_duration': ['p(95)<600'],
  },
};

const BASE_URL = __ENV.API_BASE || 'http://localhost:8080';
const TOKEN = __ENV.ACCESS_TOKEN || '';

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${TOKEN}`,
};

export default function () {
  // 1. Tạo trip
  const tripPayload = JSON.stringify({
    originText: 'UIT Campus',
    destText: 'Tan Son Nhat Airport',
    serviceId: 'bike',
  });

  const tripStart = Date.now();
  const tripRes = http.post(`${BASE_URL}/v1/trips`, tripPayload, { headers });
  const tripDuration = Date.now() - tripStart;

  tripLatency.add(tripDuration);
  const tripSuccess = tripRes.status === 201 || tripRes.status === 402;
  check(tripRes, { 'trip created': () => tripSuccess });
  
  if (tripSuccess) {
    successfulTrips.add(1);
    errorRate.add(0);
  } else {
    errorRate.add(1);
  }

  // 2. Tìm driver
  const searchStart = Date.now();
  const searchRes = http.get(
    `${BASE_URL}/v1/drivers/search?lat=10.869&lng=106.803&radius=5000`,
    { headers }
  );
  const searchDuration = Date.now() - searchStart;

  searchLatency.add(searchDuration);
  const searchSuccess = searchRes.status === 200;
  check(searchRes, { 'search ok': () => searchSuccess });
  
  if (!searchSuccess) {
    errorRate.add(1);
  }

  // Sleep ngẫu nhiên để mô phỏng user behavior thực tế
  sleep(Math.random() * 2 + 0.5); // 0.5-2.5s
}

export function handleSummary(data) {
  // Log cảnh báo nếu có dấu hiệu degradation
  const tripP95 = data.metrics.trip_create_latency?.values?.['p(95)'] || 0;
  const searchP95 = data.metrics.driver_search_latency?.values?.['p(95)'] || 0;
  const errors = data.metrics.error_rate?.values?.rate || 0;

  console.log('\n=== SOAK TEST SUMMARY ===');
  console.log(`Duration: ${SOAK_DURATION}`);
  console.log(`Trip Create p95: ${tripP95.toFixed(2)}ms`);
  console.log(`Driver Search p95: ${searchP95.toFixed(2)}ms`);
  console.log(`Error Rate: ${(errors * 100).toFixed(2)}%`);
  
  if (tripP95 > 400) {
    console.log('⚠️  WARNING: Trip latency degradation detected!');
  }
  if (errors > 0.01) {
    console.log('⚠️  WARNING: Error rate exceeded 1% threshold!');
  }

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
