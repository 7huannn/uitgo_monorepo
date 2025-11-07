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

Authentication:

```bash
# Register (201 Created)
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"UIT Rider","email":"rider@example.com","phone":"0900000000","password":"123456"}'

# Login (200 OK)
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"rider@example.com","password":"123456"}'
```

The responses contain a JWT (`token`), user id, name, and email. Pass the token via `Authorization: Bearer <token>` for authenticated requests.

Profile:

```bash
# Current user
curl http://localhost:8080/auth/me \
  -H "Authorization: Bearer <token>"

# Update name/phone
curl -X PATCH http://localhost:8080/users/me \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"UIT Rider","phone":"0900000000"}'
```

Create a trip:

```bash
curl -X POST http://localhost:8080/v1/trips \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
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

Trip history for the logged-in rider or driver (supports both `limit/offset` and `page/pageSize`):

```bash
curl "http://localhost:8080/v1/trips?role=rider&page=1&pageSize=5" \
  -H "Authorization: Bearer <token>"
```

Notifications:

```bash
# Fetch unread notifications (default limit 20)
curl "http://localhost:8080/notifications?unreadOnly=true" \
  -H "Authorization: Bearer <token>"

# Mark as read
curl -X PATCH http://localhost:8080/notifications/<notificationId>/read \
  -H "Authorization: Bearer <token>"
```

Wallet & saved places:

```bash
# Wallet summary
curl http://localhost:8080/wallet \
  -H "Authorization: Bearer <token>"

# List saved places
curl http://localhost:8080/saved_places \
  -H "Authorization: Bearer <token>"

# Create saved place
curl -X POST http://localhost:8080/saved_places \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Nhà","address":"12 Võ Oanh, Bình Thạnh","lat":10.79698,"lng":106.72098}'

# Delete saved place
curl -X DELETE http://localhost:8080/saved_places/<placeId> \
  -H "Authorization: Bearer <token>"
```

Home promotions & news:

```bash
curl http://localhost:8080/promotions \
  -H "Authorization: Bearer <token>"

curl "http://localhost:8080/news?limit=5" \
  -H "Authorization: Bearer <token>"
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

### Swagger UI

Preview the OpenAPI spec via Docker:

```bash
docker run --rm -p 8081:8080 \
  -e SWAGGER_JSON=/spec/openapi.yaml \
  -v "$PWD/backend/openapi.yaml:/spec/openapi.yaml" \
  swaggerapi/swagger-ui
```

Then open [http://localhost:8081](http://localhost:8081).

### Admin playground

A static testing console lives in [`admin/index.html`](../admin/index.html). Open it in the browser, set the API base, and you can:

- Hit `/health`, `/v1/trips`, `/v1/trips/:id`, `/v1/trips/:id/status`
- Connect to the WebSocket channel. Browsers can’t set custom headers, so the page appends `?role=` and `?userId=` query params that the backend accepts.
- Register and log in; on success the playground keeps your JWT in `localStorage` and attaches it to subsequent requests.

## Architecture Overview

- **Gin** for HTTP routing & middleware.
- **GORM** for PostgreSQL persistence (trips + trip_events tables).
- **Notifications** table stores user alerts and read state for `/notifications` endpoints.
- **WebSocket** hub per trip broadcasting location/status updates.
- `.env` configuration (`PORT`, `POSTGRES_DSN`, `CORS_ALLOWED_ORIGINS`).

Database schema is managed with SQL files under `backend/migrations`. The bootstrap migrator (`make migrate`) runs them sequentially.

OpenAPI contract lives in [`openapi.yaml`](openapi.yaml).

> The Docker entrypoint runs `/app/migrate` on every boot, so the API container always applies pending migrations before serving traffic.

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
