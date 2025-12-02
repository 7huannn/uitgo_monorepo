# UITGo Rider App

Flutter client for riders booking UITGo trips.

## Prerequisites

- Flutter 3.22+ (Dart 3.4+)
- Backend running locally (see `backend/README.md`)

## Running

```bash
flutter pub get

# Chrome / desktop
flutter run -d chrome \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE=http://localhost:8080

# Android emulator
flutter run -d emulator-5554 \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE=http://10.0.2.2:8080

# iOS simulator
flutter run -d ios \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE=http://127.0.0.1:8080
```

> For a real device, replace `API_BASE` with your machine’s LAN IP (e.g. `http://192.168.1.12:8080`).

### Mock vs Real Backend

- `USE_MOCK=true` (default) keeps data local and skips network calls.
- `USE_MOCK=false` switches to the Go backend, using the `API_BASE` you provide. The login and register screens call `/auth/login` and `/auth/register` to obtain a JWT, which is then reused for trip creation.

When connected to the backend, the “Đặt chuyến ngay” flow will:

1. `POST /v1/trips` with `Authorization: Bearer <accessToken>` (issued by `/auth/login`/`/auth/register`).
2. Open a WebSocket on `/v1/trips/{id}/ws` and attach the JWT (header on mobile/desktop, `accessToken` query parameter on Flutter web) so the server can authorise the stream.

### Troubleshooting

- If trip creation fails, confirm the backend is running (`curl http://localhost:8080/health`) and that `API_BASE` matches your environment.
- If login/register fails, ensure the backend was started with both `JWT_SECRET` and `REFRESH_TOKEN_ENCRYPTION_KEY`, and that the password meets the minimum requirements (≥ 6 characters).
- On Chrome, ensure CORS allows the origin (default backend config permits `localhost`). For WebSocket auth the app automatically appends `?accessToken=<JWT>` when running on the web.
