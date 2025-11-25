# UITGo Admin Console

Minimal HTML page to poke the backend trip API without writing curl scripts.

## Usage

```bash
# from repo root
open admin/index.html     # or use your browser's "Open File..."
```

What you can do:

- Configure the API base URL (defaults to `http://localhost:8080`).
- Call REST endpoints:
  - `GET /health`
  - `POST /auth/register`
  - `POST /auth/login`
  - `POST /v1/trips`
  - `GET /v1/trips/{id}`
  - `PATCH /v1/trips/{id}/status`
- Connect to the WebSocket channel.
  - Riders: receive live updates.
  - Drivers: send `location` and `status` messages.
- Admins: login with an admin JWT (see `ADMIN_EMAIL`/`ADMIN_PASSWORD` below) and pick `role=admin` for WS/testing protected endpoints like `/admin/me`.
- Manage JWT tokens: successful register/login responses persist the token in `localStorage` and automatically attach `Authorization: Bearer ...` to subsequent requests. Use the “Logout” button to clear it.

> Browsers cannot add custom headers to WebSocket connections. The page appends `?role=` plus `?accessToken=` query parameters which the backend accepts in place of the `Authorization`/`X-Role` headers.

## Admin seeding

If you set environment variables on the user-service (or API monolith):

- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- (optional) `ADMIN_NAME`

the service will ensure an admin user exists with that email and will mark the role as `admin`. Log in via `/auth/login` using these credentials; the issued JWT will include `role: admin` and can access `/admin/*` endpoints.

> Dev Docker Compose already seeds `admin@example.com` / `***REMOVED***` (override via envs).
