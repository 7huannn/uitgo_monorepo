import http from 'k6/http'; import { check, sleep } from 'k6';
export const options={vus:20,duration:'1m'};
const B=__ENV.API_BASE||'http://localhost:8080'; const T=__ENV.ACCESS_TOKEN||'';
export default () => {
  const h={Authorization:`Bearer ${T}`};
  check(http.get(`${B}/promotions`,{headers:h}),{ok:r=>r.status===200});
  check(http.get(`${B}/news`,{headers:h}),{ok:r=>r.status===200});
  sleep(1);
};
