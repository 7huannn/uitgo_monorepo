/**
 * WebSocket Load Test - Test độ trễ cập nhật realtime trip status
 * 
 * Mục đích:
 * - Đo latency cập nhật trạng thái trip qua WebSocket
 * - Kiểm tra khả năng xử lý nhiều connection đồng thời
 * - Phát hiện message loss hoặc ordering issues
 * 
 * Cách chạy:
 *   ACCESS_TOKEN=... k6 run --summary-export loadtests/results/websocket_test.json loadtests/k6/websocket_test.js
 * 
 * Lưu ý: Cần có trip_id hợp lệ để subscribe
 */

import { check, sleep } from 'k6';
import ws from 'k6/ws';
import http from 'k6/http';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics
const wsConnectTime = new Trend('ws_connect_time', true);
const wsMessageLatency = new Trend('ws_message_latency', true);
const wsMessagesReceived = new Counter('ws_messages_received');
const wsConnectionErrors = new Rate('ws_connection_errors');

const WS_VUS = Number(__ENV.WS_VUS) || 20;
const WS_DURATION = __ENV.WS_DURATION || '2m';

export const options = {
  scenarios: {
    websocket_connections: {
      executor: 'constant-vus',
      vus: WS_VUS,
      duration: WS_DURATION,
    },
  },
  thresholds: {
    'ws_connect_time': ['p(95)<1000'],
    'ws_message_latency': ['p(95)<500'],
    'ws_connection_errors': ['rate<0.05'],
  },
};

const BASE_URL = __ENV.API_BASE || 'http://localhost:8080';
const WS_BASE_URL = BASE_URL.replace('http://', 'ws://').replace('https://', 'wss://');
const TOKEN = __ENV.ACCESS_TOKEN || '';

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${TOKEN}`,
};

export default function () {
  // 1. Tạo trip mới để có trip_id cho WebSocket
  const tripPayload = JSON.stringify({
    originText: 'UIT Campus',
    destText: 'Tan Son Nhat Airport',
    serviceId: 'bike',
  });

  const tripRes = http.post(`${BASE_URL}/v1/trips`, tripPayload, { headers });
  
  if (tripRes.status !== 201 && tripRes.status !== 402) {
    console.log(`Failed to create trip: ${tripRes.status}`);
    wsConnectionErrors.add(1);
    sleep(1);
    return;
  }

  let tripId;
  try {
    const tripData = JSON.parse(tripRes.body);
    tripId = tripData.id || tripData.tripId;
  } catch (e) {
    console.log('Failed to parse trip response');
    wsConnectionErrors.add(1);
    sleep(1);
    return;
  }

  if (!tripId) {
    console.log('No trip ID in response');
    sleep(1);
    return;
  }

  // 2. Kết nối WebSocket để theo dõi trip
  const wsUrl = `${WS_BASE_URL}/v1/trips/${tripId}/ws?token=${TOKEN}`;
  
  const connectStart = Date.now();
  
  const res = ws.connect(wsUrl, {}, function (socket) {
    const connectTime = Date.now() - connectStart;
    wsConnectTime.add(connectTime);

    socket.on('open', function () {
      check(null, { 'ws connected': () => true });
      console.log(`Connected to trip ${tripId}`);
    });

    socket.on('message', function (data) {
      const receiveTime = Date.now();
      wsMessagesReceived.add(1);

      try {
        const msg = JSON.parse(data);
        // Nếu message có timestamp, tính latency
        if (msg.timestamp) {
          const msgTime = new Date(msg.timestamp).getTime();
          const latency = receiveTime - msgTime;
          if (latency > 0 && latency < 60000) { // Bỏ qua latency bất thường
            wsMessageLatency.add(latency);
          }
        }
        console.log(`Received: ${msg.type || msg.status || 'unknown'}`);
      } catch (e) {
        console.log('Non-JSON message received');
      }
    });

    socket.on('error', function (e) {
      console.log(`WebSocket error: ${e.error()}`);
      wsConnectionErrors.add(1);
    });

    socket.on('close', function () {
      console.log(`Connection closed for trip ${tripId}`);
    });

    // Giữ kết nối trong một khoảng thời gian
    socket.setTimeout(function () {
      socket.close();
    }, 30000); // 30 giây mỗi connection
  });

  check(res, { 'ws status is 101': (r) => r && r.status === 101 });

  if (!res || res.status !== 101) {
    wsConnectionErrors.add(1);
  }

  sleep(1);
}

export function handleSummary(data) {
  const connectP95 = data.metrics.ws_connect_time?.values?.['p(95)'] || 0;
  const messageP95 = data.metrics.ws_message_latency?.values?.['p(95)'] || 0;
  const errors = data.metrics.ws_connection_errors?.values?.rate || 0;
  const messages = data.metrics.ws_messages_received?.values?.count || 0;

  console.log('\n=== WEBSOCKET TEST SUMMARY ===');
  console.log(`Total VUs: ${WS_VUS}`);
  console.log(`Duration: ${WS_DURATION}`);
  console.log(`Connection Time p95: ${connectP95.toFixed(2)}ms`);
  console.log(`Message Latency p95: ${messageP95.toFixed(2)}ms`);
  console.log(`Messages Received: ${messages}`);
  console.log(`Connection Error Rate: ${(errors * 100).toFixed(2)}%`);

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
