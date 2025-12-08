/**
 * Stress Test - Tìm breaking point của hệ thống
 * 
 * Mục đích:
 * - Xác định giới hạn tối đa (maximum capacity) của hệ thống
 * - Tìm điểm mà error rate bắt đầu tăng đột biến
 * - Quan sát hành vi hệ thống khi vượt quá capacity
 * 
 * Cách chạy:
 *   ACCESS_TOKEN=... k6 run --summary-export loadtests/results/stress_test.json loadtests/k6/stress_test.js
 * 
 * Mô hình: Ramp-up → Stress → Ramp-down
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics để phân tích breaking point
const tripLatency = new Trend('trip_create_latency', true);
const searchLatency = new Trend('driver_search_latency', true);
const errorRate = new Rate('error_rate');
const httpErrors = new Counter('http_errors');

// Stress levels - tăng dần để tìm breaking point
const MAX_RPS = Number(__ENV.MAX_RPS) || 200;
const STRESS_DURATION = __ENV.STRESS_DURATION || '30s';

export const options = {
  scenarios: {
    stress_ramp: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      stages: [
        // Warm-up phase
        { target: 20, duration: '30s' },
        // Gradual stress increase
        { target: 50, duration: '1m' },
        { target: 100, duration: '1m' },
        { target: MAX_RPS, duration: STRESS_DURATION },
        // Recovery phase
        { target: 50, duration: '30s' },
        { target: 10, duration: '30s' },
      ],
      preAllocatedVUs: 50,
      maxVUs: 500,
    },
  },
  thresholds: {
    // Thresholds ở mức cao hơn vì đây là stress test
    'http_req_duration': ['p(95)<2000'],
    'trip_create_latency': ['p(95)<3000'],
    'driver_search_latency': ['p(95)<1000'],
  },
};

const BASE_URL = __ENV.API_BASE || 'http://localhost:8080';
const TOKEN = __ENV.ACCESS_TOKEN || '';

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${TOKEN}`,
};

export default function () {
  // Mix of operations để mô phỏng workload thực tế
  const operation = Math.random();

  if (operation < 0.6) {
    // 60% - Tạo trip (heavy operation)
    createTrip();
  } else if (operation < 0.9) {
    // 30% - Tìm driver (medium operation)
    searchDriver();
  } else {
    // 10% - Get trip list (light operation)
    getTrips();
  }

  sleep(0.1 + Math.random() * 0.4); // 0.1-0.5s
}

function createTrip() {
  const payload = JSON.stringify({
    originText: 'UIT Campus',
    destText: 'Tan Son Nhat Airport',
    serviceId: 'bike',
  });

  const start = Date.now();
  const res = http.post(`${BASE_URL}/v1/trips`, payload, { headers, timeout: '10s' });
  tripLatency.add(Date.now() - start);

  const success = res.status === 201 || res.status === 402;
  check(res, { 'trip created': () => success });
  
  if (!success) {
    httpErrors.add(1);
    errorRate.add(1);
  } else {
    errorRate.add(0);
  }
}

function searchDriver() {
  const start = Date.now();
  const res = http.get(
    `${BASE_URL}/v1/drivers/search?lat=10.869&lng=106.803&radius=5000`,
    { headers, timeout: '5s' }
  );
  searchLatency.add(Date.now() - start);

  const success = res.status === 200;
  check(res, { 'search ok': () => success });
  
  if (!success) {
    httpErrors.add(1);
    errorRate.add(1);
  } else {
    errorRate.add(0);
  }
}

function getTrips() {
  const res = http.get(`${BASE_URL}/v1/trips?limit=10`, { headers, timeout: '5s' });
  const success = res.status === 200;
  check(res, { 'trips list ok': () => success });
  
  if (!success) {
    httpErrors.add(1);
    errorRate.add(1);
  } else {
    errorRate.add(0);
  }
}

export function handleSummary(data) {
  const tripP95 = data.metrics.trip_create_latency?.values?.['p(95)'] || 0;
  const tripP99 = data.metrics.trip_create_latency?.values?.['p(99)'] || 0;
  const searchP95 = data.metrics.driver_search_latency?.values?.['p(95)'] || 0;
  const errors = data.metrics.error_rate?.values?.rate || 0;
  const totalErrors = data.metrics.http_errors?.values?.count || 0;
  const totalReqs = data.metrics.http_reqs?.values?.count || 0;
  const maxRps = data.metrics.http_reqs?.values?.rate || 0;

  console.log('\n=== STRESS TEST SUMMARY ===');
  console.log(`Max Target RPS: ${MAX_RPS}`);
  console.log(`Achieved RPS: ${maxRps.toFixed(2)}`);
  console.log(`Total Requests: ${totalReqs}`);
  console.log(`Total Errors: ${totalErrors}`);
  console.log(`Error Rate: ${(errors * 100).toFixed(2)}%`);
  console.log(`Trip Create p95: ${tripP95.toFixed(2)}ms`);
  console.log(`Trip Create p99: ${tripP99.toFixed(2)}ms`);
  console.log(`Driver Search p95: ${searchP95.toFixed(2)}ms`);

  // Phân tích breaking point
  if (errors > 0.1) {
    console.log('\n🔴 BREAKING POINT DETECTED: Error rate > 10%');
    console.log('   → Hệ thống đã quá tải, cần scale hoặc tối ưu');
  } else if (errors > 0.05) {
    console.log('\n🟡 WARNING: Error rate 5-10%');
    console.log('   → Gần đạt giới hạn capacity');
  } else if (tripP95 > 1000) {
    console.log('\n🟡 WARNING: Latency degradation detected (p95 > 1s)');
    console.log('   → Cân nhắc scale trước khi errors tăng');
  } else {
    console.log('\n🟢 System handled stress well');
  }

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
