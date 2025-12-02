# ADR-004: Chọn Docker Compose + ASG/Terraform cho staging

- **Status:** Accepted

## Context
- Cần môi trường staging giống dev để demo và test tích hợp, trong khi đội nhỏ và thời gian giới hạn.
- Repo đã có `docker-compose.yml` đầy đủ (gateway + 3 service + Redis + Prometheus + Grafana).
- Hạ tầng AWS hiện có quyền tạo EC2/ASG/RDS nhưng chưa đủ bandwidth để dựng EKS/ECS bài bản.

## Options Considered
- **1 EC2 chạy docker-compose thủ công:** nhanh nhưng đơn điểm lỗi, khó tự động hóa, khó scale.
- **Docker Compose + Auto Scaling Group (Terraform modules):** tận dụng compose hiện có, khởi động stack qua user_data trong ASG, có thể tăng số node theo CPU/backlog.
- **ECS/EKS:** phù hợp production, scale tốt, nhưng cần thêm thời gian để viết task definition/helm chart, thiết lập registry/ALB/service mesh.

## Decision
- Dùng Terraform scaffold trong `infra/terraform` để tạo VPC, RDS, Redis, (tuỳ chọn SQS), và **một ASG** khởi chạy script `backend.sh.tpl` chạy `docker compose up`. Đây là staging khởi đầu, đủ cho demo và test pipeline.

## Consequences / Trade-offs
- **Ưu:** nhanh, tận dụng cấu hình compose sẵn; pipeline CI/CD chỉ cần build/push image rồi ASG kéo về; chi phí thấp hơn EKS/ECS.
- **Nhược:** scale theo node, không scale độc lập từng service; cùng failure domain (1 ASG); chưa đạt mức HA đa-AZ; logging/secret management đơn giản (file env) nên cần nâng cấp nếu lên production.
