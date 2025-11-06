# UITGo Backend

Go service powering the UITGo rider and driver applications. It exposes a minimal trip API backed by PostgreSQL and streams driver locations over WebSocket.

## Prerequisites

- Go 1.22 (or higher) if you plan to run locally without Docker.
- Docker & Docker Compose v2 for containerised development.
- `make`

## Getting Started

```bash
cp backend/.env.example backend/.env   # adjust credentials if needed
cd backend
make dev                               # builds the image, starts postgres + api
```

Services start on:

- HTTP API: `http://localhost:8080`
- PostgreSQL: `localhost:5432` (user/pass `uitgo/uitgo`, db `uitgo`)

To stop the stack:

```bash
make down
```

### Local development without Docker

```bash
cd backend
make migrate     # applies SQL migrations against the configured POSTGRES_DSN
make run         # starts the HTTP server on $PORT (default 8080)
```

### Helpful commands

```bash
make test   # run Go unit tests
make fmt    # gofmt all packages
make tidy   # tidy go.mod / go.sum
```

## API Quickstart

Health check:

```bash
curl http://localhost:8080/health
```

Create a trip:

```bash
curl -X POST http://localhost:8080/v1/trips \
  -H "Content-Type: application/json" \
  -H "X-User-Id: rider-123" \
  -d '{"originText":"UIT Campus A","destText":"Dormitory","serviceId":"UIT-Bike"}'
```

Fetch a trip (replace `<tripId>`):

```bash
curl http://localhost:8080/v1/trips/<tripId>
```

Update status:

```bash
curl -X PATCH http://localhost:8080/v1/trips/<tripId>/status \
  -H "Content-Type: application/json" \
  -d '{"status":"arriving"}'
```

WebSocket (requires `wscat` or similar):

```bash
# Rider subscriber
wscat -c ws://localhost:8080/v1/trips/<tripId>/ws

# Driver publishing locations
wscat -c ws://localhost:8080/v1/trips/<tripId>/ws -H "X-Role: driver"
> {"type":"location","lat":10.8705,"lng":106.8032}
```

Each driver location message is persisted to `trip_events` and fanned out to all connected riders and drivers on that trip.

## Architecture Overview

- **Gin** for HTTP routing & middleware.
- **GORM** for PostgreSQL persistence (trips + trip_events tables).
- **WebSocket** hub per trip broadcasting location/status updates.
- `.env` configuration (`PORT`, `POSTGRES_DSN`, `CORS_ALLOWED_ORIGINS`).

Database schema is managed with SQL files under `backend/migrations`. The bootstrap migrator (`make migrate`) runs them sequentially.

OpenAPI contract lives in [`openapi.yaml`](openapi.yaml).

## Flutter Rider App Integration Notes

- **Create Trip:** `POST /v1/trips` with body `{originText, destText, serviceId}`. Include `X-User-Id` header until real auth arrives.
- **Fetch Trip:** `GET /v1/trips/{id}` returns the trip plus `lastLocation` (if the driver has reported one).
- **Realtime Channel:** connect to `ws://{API_BASE_HOST}/v1/trips/{id}/ws`.
  - Riders simply listen for messages.
  - Drivers connect with header `X-Role: driver` and push `{"type":"location","lat":10.1,"lng":106.2}`.

Minimal Dart snippet:

```dart
final socket = WebSocketChannel.connect(
  Uri.parse('ws://localhost:8080/v1/trips/$tripId/ws'),
  headers: {'X-User-Id': riderId},
);

socket.stream.listen((event) {
  final data = jsonDecode(event as String);
  if (data['type'] == 'location') {
    final lat = (data['location']['lat'] as num).toDouble();
    final lng = (data['location']['lng'] as num).toDouble();
    // update map marker here
  }
});
```

Drivers can send updates (e.g. using `web_socket_channel`) by writing JSON payloads through `socket.sink.add`.
