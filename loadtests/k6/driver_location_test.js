/**
 * Driver Location Update Test - Luồng cập nhật vị trí driver
 * 
 * Mục đích:
 * - Test khả năng xử lý cập nhật vị trí liên tục từ nhiều driver
 * - Kiểm tra Redis GEO performance dưới tải cao
 * - Đo latency của geo-indexing và query
 * 
 * Cách chạy:
 *   DRIVER_TOKEN=... k6 run --summary-export loadtests/results/driver_location_test.json loadtests/k6/driver_location_test.js
 * 
 * Lưu ý: Cần token của driver account
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics
const locationUpdateLatency = new Trend('location_update_latency', true);
const geoQueryLatency = new Trend('geo_query_latency', true);
const updateErrors = new Rate('update_error_rate');
const updatesSuccessful = new Counter('successful_updates');

// Cấu hình
const NUM_DRIVERS = Number(__ENV.NUM_DRIVERS) || 50;
const UPDATE_INTERVAL = Number(__ENV.UPDATE_INTERVAL) || 3; // seconds
const TEST_DURATION = __ENV.TEST_DURATION || '3m';

export const options = {
  scenarios: {
    driver_updates: {
      executor: 'constant-vus',
      vus: NUM_DRIVERS,
      duration: TEST_DURATION,
    },
  },
  thresholds: {
    'location_update_latency': ['p(95)<100', 'avg<50'],
    'geo_query_latency': ['p(95)<150', 'avg<80'],
    'update_error_rate': ['rate<0.01'],
  },
};

const BASE_URL = __ENV.API_BASE || 'http://localhost:8080';
// Dùng DRIVER_TOKEN hoặc fallback về ACCESS_TOKEN
const TOKEN = __ENV.DRIVER_TOKEN || __ENV.ACCESS_TOKEN || '';

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${TOKEN}`,
};

// Vùng HCM - UIT area
const BASE_LAT = 10.869;
const BASE_LNG = 106.803;

// Mô phỏng di chuyển của driver
function simulateMovement(vuId, iteration) {
  // Di chuyển ngẫu nhiên trong bán kính ~2km quanh UIT
  const angle = (iteration * 0.1 + vuId * 0.5) % (2 * Math.PI);
  const radius = 0.01 + Math.random() * 0.01; // ~1-2km
  
  return {
    lat: BASE_LAT + radius * Math.cos(angle),
    lng: BASE_LNG + radius * Math.sin(angle),
  };
}

export default function () {
  const vuId = __VU;
  const iteration = __ITER;
  
  // 1. Cập nhật vị trí driver
  const location = simulateMovement(vuId, iteration);
  const updatePayload = JSON.stringify({
    latitude: location.lat,
    longitude: location.lng,
    heading: Math.random() * 360,
    speed: 20 + Math.random() * 40, // 20-60 km/h
  });

  const updateStart = Date.now();
  const updateRes = http.post(`${BASE_URL}/v1/drivers/location`, updatePayload, { headers });
  const updateDuration = Date.now() - updateStart;
  
  locationUpdateLatency.add(updateDuration);
  
  const updateSuccess = updateRes.status === 200 || updateRes.status === 204;
  check(updateRes, { 'location updated': () => updateSuccess });
  
  if (updateSuccess) {
    updatesSuccessful.add(1);
    updateErrors.add(0);
  } else {
    updateErrors.add(1);
  }

  // 2. Mỗi 5 lần update, thực hiện 1 geo query để verify
  if (iteration % 5 === 0) {
    const queryStart = Date.now();
    const queryRes = http.get(
      `${BASE_URL}/v1/drivers/search?lat=${location.lat}&lng=${location.lng}&radius=3000`,
      { headers }
    );
    const queryDuration = Date.now() - queryStart;
    
    geoQueryLatency.add(queryDuration);
    
    check(queryRes, { 
      'geo query ok': (r) => r.status === 200,
      'found drivers': (r) => {
        try {
          const data = JSON.parse(r.body);
          return Array.isArray(data.drivers) && data.drivers.length > 0;
        } catch (e) {
          return false;
        }
      }
    });
  }

  // Sleep theo interval cấu hình (mô phỏng GPS update interval)
  sleep(UPDATE_INTERVAL);
}

export function handleSummary(data) {
  const updateP95 = data.metrics.location_update_latency?.values?.['p(95)'] || 0;
  const updateAvg = data.metrics.location_update_latency?.values?.avg || 0;
  const queryP95 = data.metrics.geo_query_latency?.values?.['p(95)'] || 0;
  const errors = data.metrics.update_error_rate?.values?.rate || 0;
  const totalUpdates = data.metrics.successful_updates?.values?.count || 0;
  
  // Tính updates per second
  const durationSec = parseInt(TEST_DURATION) * 60 || 180;
  const updatesPerSec = totalUpdates / durationSec;

  console.log('\n=== DRIVER LOCATION UPDATE TEST SUMMARY ===');
  console.log(`Simulated Drivers: ${NUM_DRIVERS}`);
  console.log(`Test Duration: ${TEST_DURATION}`);
  console.log(`Update Interval: ${UPDATE_INTERVAL}s`);
  console.log(`Total Successful Updates: ${totalUpdates}`);
  console.log(`Updates/second: ${updatesPerSec.toFixed(2)}`);
  console.log(`Location Update Latency (avg): ${updateAvg.toFixed(2)}ms`);
  console.log(`Location Update Latency (p95): ${updateP95.toFixed(2)}ms`);
  console.log(`Geo Query Latency (p95): ${queryP95.toFixed(2)}ms`);
  console.log(`Error Rate: ${(errors * 100).toFixed(2)}%`);

  // Đánh giá Redis GEO performance
  if (updateP95 < 50 && queryP95 < 100) {
    console.log('\n🟢 Redis GEO performing excellently');
  } else if (updateP95 < 100 && queryP95 < 200) {
    console.log('\n🟢 Redis GEO performance acceptable');
  } else {
    console.log('\n🟡 Consider Redis scaling or connection pooling');
  }

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
