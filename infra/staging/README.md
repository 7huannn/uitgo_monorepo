# Staging (docker-compose on a VM)

Small compose file for a quick staging stack on a single VM. It currently uses the legacy monolith image (`uitgo-backend`) plus Postgres + nginx gateway. For the full microservice stack on EC2/ASG, use the Terraform user-data in `infra/terraform/envs/dev/user_data/backend.sh.tpl`.

## Cách dùng nhanh
1) Chuẩn bị image: `docker build -t ghcr.io/<owner>/uitgo-backend:<tag> -f backend/Dockerfile backend && docker push ...`
2) Copy `.env.staging.example` thành `.env.staging`, đặt mật khẩu/secrets phù hợp.
3) `REGISTRY_OWNER=<owner> IMAGE_TAG=<tag> docker compose up -d`

Compose này chỉ phù hợp khi bạn muốn chạy nhanh một node staging. Nếu đã có 3 image microservice (user/trip/driver), khuyến nghị dùng compose toàn cục ở repo root (hoặc script ASG trong Terraform) để giữ đúng kiến trúc microservice.
