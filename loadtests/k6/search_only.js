import http from 'k6/http'; import { check, sleep } from 'k6';
export const options = { vus: 20, duration: '1m', thresholds: { http_req_duration: ['p(95)<400'] } };
const BASE=__ENV.API_BASE||'http://localhost:8080'; const TOKEN=__ENV.ACCESS_TOKEN||'';
export default () => {
  const h={Authorization:`Bearer ${TOKEN}`};
  const res=http.get(`${BASE}/v1/drivers/search?lat=10.869&lng=106.803&radius=5000`,{headers:h});
  check(res,{ok:r=>r.status===200});
  sleep(1);
};
