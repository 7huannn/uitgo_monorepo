import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    riders: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      stages: [
        { target: 50, duration: '1m' },
        { target: 50, duration: '2m' },
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
  check(res, {
    'trip created': (r) => r.status === 201 || r.status === 402,
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
