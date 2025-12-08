import http from 'k6/http';
import { check, sleep } from 'k6';

// TARGET_RPS allows overriding the rider arrival rate without changing defaults.
const TARGET_RPS = Number(__ENV.TARGET_RPS) || 50;
const START_RATE = Number.isFinite(TARGET_RPS) && TARGET_RPS > 0 ? Math.max(1, Math.round(TARGET_RPS / 5)) : 10;

export const options = {
  scenarios: {
    riders: {
      executor: 'ramping-arrival-rate',
      startRate: START_RATE,
      timeUnit: '1s',
      stages: [
        { target: TARGET_RPS, duration: '1m' },
        { target: TARGET_RPS, duration: '2m' },
        { target: 0, duration: '30s' },
      ],
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
    driverSearch: {
      executor: 'constant-arrival-rate',
      rate: 40,
      timeUnit: '1s',
      duration: '2m',
      gracefulStop: '10s',
      preAllocatedVUs: 20,
      exec: 'searchScenario',
    },
  },
};

const BASE_URL = __ENV.API_BASE || 'http://localhost:8080';
const TOKEN = __ENV.ACCESS_TOKEN || '';

// Track rate limited requests separately
import { Counter } from 'k6/metrics';
const rateLimitedRequests = new Counter('rate_limited_requests');

export default function tripScenario() {
  const payload = JSON.stringify({
    originText: 'UIT Campus',
    destText: 'Tan Son Nhat Airport',
    serviceId: 'bike',
  });
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${TOKEN}`,
  };
  const res = http.post(`${BASE_URL}/v1/trips`, payload, { headers });
  
  // Track rate limited requests
  if (res.status === 429) {
    rateLimitedRequests.add(1);
  }
  
  check(res, {
    // 201 = created, 402 = insufficient balance, 429 = rate limited (expected in load test)
    'trip created or rate limited': (r) => r.status === 201 || r.status === 402 || r.status === 429,
  });
  sleep(1);
}

export function searchScenario() {
  const headers = { Authorization: `Bearer ${TOKEN}` };
  const res = http.get(`${BASE_URL}/v1/drivers/search?lat=10.869&lng=106.803&radius=5000`, { headers });
  check(res, {
    'search ok': (r) => r.status === 200,
  });
}
