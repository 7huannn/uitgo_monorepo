# UITGo Backend – Stage 1 Microservice Skeleton

## Services

| Service | Responsibility | Port | Backing DB |
| --- | --- | --- | --- |
| user-service | authentication, user profile, wallet/saved places, notifications | 8081 | `user_service` schema | 
| trip-service | trip lifecycle, status tracking, websocket streaming | 8082 | `trip_service` schema |
| driver-service | driver onboarding, availability, dispatch + trip actions | 8083 | `driver_service` schema |
| api-gateway | routes Flutter app traffic to the correct service | 8080 | — |

All inter-service communication happens over HTTP within the `uitgo-net` Docker network. Sensitive internal endpoints require the `X-Internal-Token` header (value comes from `INTERNAL_API_KEY`).

## Environment variables

| Variable | user-service | trip-service | driver-service |
| --- | --- | --- | --- |
| `PORT` | ✔ | ✔ | ✔ |
| `POSTGRES_DSN` | ✔ | ✔ | ✔ |
| `JWT_SECRET` | ✔ | ✔ | ✔ |
| `CORS_ALLOWED_ORIGINS` | ✔ | ✔ | ✔ |
| `DRIVER_SERVICE_URL` | ✔ | ✔ | — |
| `TRIP_SERVICE_URL` | — | ✔ (for websocket driver pings) | ✔ |
| `INTERNAL_API_KEY` | ✔ (calls driver-service) | ✔ (calls driver-service) | ✔ (validates user/trip-service calls) |

## Flutter configuration

Point both Rider and Driver apps to the API gateway (`http://localhost:8080` by default). Existing endpoints continue to work:

- `/auth/*`, `/users/*`, `/wallet`, `/saved_places`, `/promotions`, `/news`, `/notifications`, `/v1/drivers/register` → user-service
- `/v1/trips*`, `/v1/trips/:id/ws` → trip-service
- `/v1/drivers/*`, `/v1/trips/:id/(assign|accept|decline|status)` → driver-service

No Dart code changes are required beyond updating `API_BASE` if you previously targeted the monolith port.

## Local development

```bash
# build + start everything
docker compose up --build

# tear down
docker compose down -v
```

Use the individual Dockerfiles inside `backend/{user_service,trip_service,driver_service}` for standalone builds. Each binary runs its own migrations during startup.

## AWS Terraform scaffold

Under `infra/terraform` you’ll find a thin scaffold for Stage 1 infrastructure:

- `modules/network` provisions a VPC with configurable public/private subnets.
- `modules/rds` provisions Postgres instances (security groups + subnet groups).
- `envs/dev` wires the modules together for three isolated RDS instances.

Set `TF_VAR_db_password` (or create a `dev.tfvars`) before running `terraform init && terraform apply` inside `infra/terraform/envs/dev`.
