# UIT-Go Admin Web

Flutter web admin console to replace the old `admin/index.html`.

## Features

- Configure API base URL and ping `/health`.
- Admin login (`/auth/login`) and verify `/admin/me`.
- Quick user tools: register rider or driver.
- Trip tools: create trips, fetch by id, assign driver, update status.
- Realtime: connect to `/v1/trips/{id}/ws` as rider/driver/admin and send driver status/location.
- Activity log for API and WS events.

## Run locally

```bash
# from repo root
cd apps/admin_app
flutter pub get
flutter run -d chrome --web-renderer html
```

Set the API base (default `http://localhost:8080`), log in with an admin account
(dev compose seeds `admin@example.com` / `admin123`), then start managing trips.
