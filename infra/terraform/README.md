# Terraform (dev scaffold)

Hạ tầng mẫu để chạy stack microservice trên AWS:
- VPC + subnet public/private, security groups.
- 3 RDS Postgres (user/trip/driver) + optional trip replica.
- Redis (ElastiCache) cho geo/queue + SQS hàng đợi ghép chuyến.
- ALB + ASG user-data chạy Docker Compose (gateway + 3 service). **Chưa** wire ECS/EKS.

## Yêu cầu
- Terraform >= 1.5
- AWS credentials (ví dụ `export AWS_PROFILE=<profile>` hoặc `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`).
- Docker images đã push lên registry (GHCR/ECR).

## Cấu trúc
- `modules/network`, `modules/rds`, `modules/redis`, `modules/sqs`, `modules/asg_service`
- `envs/dev`: ghép module + user-data `user_data/backend.sh.tpl` để EC2 chạy `docker compose up`.

## Nhanh gọn (envs/dev)
```bash
cd infra/terraform/envs/dev

# Tạo terraform.tfvars hoặc truyền -var, tối thiểu cần:
# db_password     = "..."
# trip_service_ami = "ami-xxxx"   # AMI có docker + compose plugin được hỗ trợ (Amazon Linux 2/Ubuntu)
# container_registry = "ghcr.io/uitgo"   # hoặc <aws_account_id>.dkr.ecr.<region>.amazonaws.com
# backend_image_tag  = "v0.1.0"          # tag đã push cho 3 images user/trip/driver

terraform init
terraform plan  -var db_password=... -var trip_service_ami=ami-...
terraform apply -var db_password=... -var trip_service_ami=ami-...
```

Defaults thân thiện dev: `ap-southeast-1`, VPC `10.60.0.0/16`, RDS `db.t4g.micro` (20GB), Redis `cache.t3.micro`. Override bằng `terraform.tfvars` nếu cần.

### Build & push images (ví dụ GHCR/ECR)
```bash
TAG=v0.1.0
REG=ghcr.io/<owner>
docker build -t $REG/uitgo-user-service:$TAG -f backend/user_service/Dockerfile .
docker build -t $REG/uitgo-trip-service:$TAG -f backend/trip_service/Dockerfile .
docker build -t $REG/uitgo-driver-service:$TAG -f backend/driver_service/Dockerfile .
docker push $REG/uitgo-{user,trip,driver}-service:$TAG
```

ASG user-data (`user_data/backend.sh.tpl`) sẽ pull 3 images ở registry + chạy gateway nginx/compose trên EC2. Outputs sau apply cung cấp endpoint RDS/Redis/SQS/ALB để điền vào `.env`/secrets nếu cần.

### Ghi chú
- Chưa cấu hình HTTPS mặc định; đặt `alb_certificate_arn` nếu có ACM để bật listener 443.
- Hạ tầng này chỉ dựng network + backing store + ASG chạy docker compose; chưa có ECS/EKS, autoscaling dựa vào ASG size.
