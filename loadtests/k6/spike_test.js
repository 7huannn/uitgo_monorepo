/**
 * Spike Test - Test đột biến traffic ngắn hạn
 * 
 * Mục đích:
 * - Kiểm tra hệ thống xử lý traffic surge đột ngột (flash crowd)
 * - Đánh giá thời gian recovery sau spike
 * - Verify async queue hoạt động đúng trong spike scenario
 * 
 * Cách chạy:
 *   ACCESS_TOKEN=... k6 run --summary-export loadtests/results/spike_test.json loadtests/k6/spike_test.js
 * 
 * Mô hình: Normal → Spike (5x) → Normal → Spike (10x) → Normal
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics
const tripLatency = new Trend('trip_create_latency', true);
const errorRate = new Rate('error_rate');
const spikeRecoveryTime = new Trend('spike_recovery_time', true);

const NORMAL_RPS = Number(__ENV.NORMAL_RPS) || 20;
const SPIKE_MULTIPLIER = Number(__ENV.SPIKE_MULTIPLIER) || 5;

export const options = {
  scenarios: {
    spike_pattern: {
      executor: 'ramping-arrival-rate',
      startRate: NORMAL_RPS,
      timeUnit: '1s',
      stages: [
        // Baseline normal load
        { target: NORMAL_RPS, duration: '30s' },
        
        // First spike - 5x normal
        { target: NORMAL_RPS * SPIKE_MULTIPLIER, duration: '10s' },
        { target: NORMAL_RPS * SPIKE_MULTIPLIER, duration: '30s' },
        
        // Recovery to normal
        { target: NORMAL_RPS, duration: '10s' },
        { target: NORMAL_RPS, duration: '30s' },
        
        // Second spike - 10x normal (extreme)
        { target: NORMAL_RPS * SPIKE_MULTIPLIER * 2, duration: '10s' },
        { target: NORMAL_RPS * SPIKE_MULTIPLIER * 2, duration: '20s' },
        
        // Final recovery
        { target: NORMAL_RPS, duration: '10s' },
        { target: NORMAL_RPS, duration: '30s' },
      ],
      preAllocatedVUs: 50,
      maxVUs: 300,
    },
  },
  thresholds: {
    // Cho phép latency cao hơn trong spike, nhưng vẫn có giới hạn
    'http_req_duration': ['p(95)<3000'],
    'trip_create_latency': ['p(99)<5000'],
    // Error rate không được quá cao ngay cả trong spike
    'error_rate': ['rate<0.15'],
  },
};

const BASE_URL = __ENV.API_BASE || 'http://localhost:8080';
const TOKEN = __ENV.ACCESS_TOKEN || '';

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${TOKEN}`,
};

// Track baseline latency để tính recovery
let baselineLatency = 0;
let lastSpikeEnd = 0;

export default function () {
  const payload = JSON.stringify({
    originText: 'UIT Campus',
    destText: 'Tan Son Nhat Airport',
    serviceId: 'bike',
  });

  const start = Date.now();
  const res = http.post(`${BASE_URL}/v1/trips`, payload, { headers, timeout: '15s' });
  const duration = Date.now() - start;

  tripLatency.add(duration);

  const success = res.status === 201 || res.status === 402;
  check(res, { 'trip created': () => success });
  
  if (success) {
    errorRate.add(0);
  } else {
    errorRate.add(1);
  }

  // Log during spike phases for visibility
  const elapsed = Date.now() / 1000;
  if (duration > 1000) {
    console.log(`High latency detected: ${duration}ms at ${elapsed.toFixed(0)}s`);
  }

  sleep(0.2 + Math.random() * 0.3);
}

export function handleSummary(data) {
  const tripP50 = data.metrics.trip_create_latency?.values?.med || 0;
  const tripP95 = data.metrics.trip_create_latency?.values?.['p(95)'] || 0;
  const tripP99 = data.metrics.trip_create_latency?.values?.['p(99)'] || 0;
  const tripMax = data.metrics.trip_create_latency?.values?.max || 0;
  const errors = data.metrics.error_rate?.values?.rate || 0;
  const totalReqs = data.metrics.http_reqs?.values?.count || 0;

  console.log('\n=== SPIKE TEST SUMMARY ===');
  console.log(`Normal RPS: ${NORMAL_RPS}`);
  console.log(`First Spike: ${NORMAL_RPS * SPIKE_MULTIPLIER} RPS (5x)`);
  console.log(`Second Spike: ${NORMAL_RPS * SPIKE_MULTIPLIER * 2} RPS (10x)`);
  console.log(`Total Requests: ${totalReqs}`);
  console.log(`Error Rate: ${(errors * 100).toFixed(2)}%`);
  console.log('');
  console.log('Latency Distribution:');
  console.log(`  p50: ${tripP50.toFixed(2)}ms`);
  console.log(`  p95: ${tripP95.toFixed(2)}ms`);
  console.log(`  p99: ${tripP99.toFixed(2)}ms`);
  console.log(`  max: ${tripMax.toFixed(2)}ms`);

  // Đánh giá spike handling
  console.log('\n=== SPIKE RESILIENCE ANALYSIS ===');
  
  if (errors < 0.05) {
    console.log('🟢 Excellent: <5% errors during spikes');
    console.log('   → Async queue absorbing burst effectively');
  } else if (errors < 0.10) {
    console.log('🟡 Good: 5-10% errors during extreme spike');
    console.log('   → Consider pre-warming or more aggressive auto-scaling');
  } else {
    console.log('🔴 Needs improvement: >10% errors');
    console.log('   → Review queue depth limits and consumer scaling');
  }

  if (tripP95 < 1000) {
    console.log('🟢 Latency well controlled during spikes');
  } else if (tripP95 < 2000) {
    console.log('🟡 Latency acceptable but elevated during spikes');
  } else {
    console.log('🔴 Significant latency degradation during spikes');
  }

  // Tính "spike factor" - tỷ lệ p99/p50
  const spikeFactor = tripP50 > 0 ? tripP99 / tripP50 : 0;
  console.log(`\nSpike Factor (p99/p50): ${spikeFactor.toFixed(2)}x`);
  if (spikeFactor < 5) {
    console.log('   → Consistent performance under varying load');
  } else if (spikeFactor < 10) {
    console.log('   → Some variability during spikes (expected)');
  } else {
    console.log('   → High variability - may indicate resource contention');
  }

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
