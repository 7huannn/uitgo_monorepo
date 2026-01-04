# End-to-End DevOps Setup Guide

Hướng dẫn này mô tả cách thiết lập pipeline CI/CD hoàn chỉnh cho UITGo, từ code commit đến production deployment.

## 📋 Tổng quan kiến trúc

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│   Git Push  │───▶│  GitHub CI   │───▶│  GHCR Push  │───▶│ Kustomize    │
│  (dev/main) │    │  (test/lint) │    │  (images)   │    │ Update       │
└─────────────┘    └──────────────┘    └─────────────┘    └──────┬───────┘
                                                                  │
                   ┌──────────────┐    ┌─────────────┐           │
                   │   K8s/EKS    │◀───│  ArgoCD     │◀──────────┘
                   │  (pods run)  │    │ (auto-sync) │
                   └──────────────┘    └─────────────┘
```

## 🔐 1. GitHub Secrets Setup

Tạo các secrets sau trong GitHub Repository Settings → Secrets and variables → Actions:

### Secrets cho CI/CD cơ bản (Bắt buộc)
| Secret Name | Mô tả | Ví dụ |
|-------------|-------|-------|
| `GITHUB_TOKEN` | Tự động có sẵn | - |

### Secrets cho Staging Environment
| Secret Name | Mô tả | Ví dụ |
|-------------|-------|-------|
| `STAGING_POSTGRES_USER` | DB username | `uitgo` |
| `STAGING_POSTGRES_PASSWORD` | DB password | `<strong-password>` |
| `STAGING_JWT_SECRET` | JWT signing key (min 32 chars) | `<random-string>` |
| `STAGING_REFRESH_TOKEN_ENCRYPTION_KEY` | Refresh token key (32 bytes) | `<32-char-string>` |
| `STAGING_INTERNAL_API_KEY` | Service-to-service API key | `<random-string>` |

### Secrets cho SealedSecrets (GitOps Secrets)
| Secret Name | Mô tả | Cách lấy |
|-------------|-------|----------|
| `SEALED_SECRETS_CERT` | Public cert từ cluster | `kubeseal --fetch-cert` |
| `POSTGRES_USER` | Production DB user | - |
| `POSTGRES_PASSWORD` | Production DB password | - |
| `JWT_SECRET` | Production JWT key | - |
| `REFRESH_TOKEN_ENCRYPTION_KEY` | Production refresh key | - |
| `INTERNAL_API_KEY` | Production API key | - |
| `ADMIN_EMAIL` | Initial admin email | - |
| `ADMIN_PASSWORD` | Initial admin password | - |
| `ADMIN_NAME` | Initial admin name | - |

### Secrets cho ArgoCD Verification (Optional)
| Secret Name | Mô tả | Cách lấy |
|-------------|-------|----------|
| `ARGOCD_SERVER` | ArgoCD server URL | `argocd.example.com` |
| `ARGOCD_AUTH_TOKEN` | ArgoCD API token | ArgoCD UI → Settings → Accounts |

### Secrets cho Terraform (Optional)
| Secret Name | Mô tả |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `TF_STATE_BUCKET` | S3 bucket for state |
| `TF_LOCK_TABLE` | DynamoDB table for locking |

## 🔧 2. Cluster Setup

### 2.1 Cài đặt SealedSecrets Controller

```bash
# Apply SealedSecrets controller
kubectl apply -f k8s/base/sealed-secrets-controller.yaml

# Wait for controller to be ready
kubectl -n sealed-secrets rollout status deployment/sealed-secrets-controller

# Fetch public key (cần cho GitHub Secret SEALED_SECRETS_CERT)
kubeseal --fetch-cert > pub-sealed-secrets.pem
cat pub-sealed-secrets.pem  # Copy nội dung này vào GitHub Secret
```

### 2.2 Cài đặt ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl -n argocd rollout status deployment/argocd-server

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Apply ArgoCD applications
kubectl apply -f k8s/argocd/project.yaml
kubectl apply -f k8s/argocd/uitgo-dev.yaml
kubectl apply -f k8s/argocd/uitgo-staging.yaml
```

### 2.3 Tạo ArgoCD API Token (cho CI verification)

```bash
# Login vào ArgoCD
argocd login <ARGOCD_SERVER> --username admin --password <password>

# Tạo API token
argocd account generate-token --account admin

# Copy token vào GitHub Secret ARGOCD_AUTH_TOKEN
```

## 🚀 3. First-time Secrets Sealing

Sau khi setup xong, chạy workflow để seal secrets:

1. Go to GitHub → Actions → "Seal Secrets"
2. Click "Run workflow"
3. Select environment (dev hoặc staging)
4. Workflow sẽ tự động commit sealed secrets

Hoặc seal thủ công:

```bash
# Tạo file secrets tạm
cat > /tmp/secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: uitgo-secrets
  namespace: uitgo
type: Opaque
stringData:
  POSTGRES_USER: "uitgo"
  POSTGRES_PASSWORD: "your-password"
  JWT_SECRET: "your-jwt-secret-min-32-characters"
  REFRESH_TOKEN_ENCRYPTION_KEY: "32-byte-encryption-key-here!!!"
  INTERNAL_API_KEY: "your-internal-api-key"
  ADMIN_EMAIL: "admin@uitgo.app"
  ADMIN_PASSWORD: "admin-password"
  ADMIN_NAME: "Admin"
EOF

# Seal secrets
kubeseal --cert pub-sealed-secrets.pem --format yaml < /tmp/secrets.yaml > k8s/overlays/dev/sealed-secrets.yaml

# Xóa file tạm ngay lập tức
rm /tmp/secrets.yaml

# Commit và push
git add k8s/overlays/dev/sealed-secrets.yaml
git commit -m "chore: add sealed secrets for dev"
git push
```

## 🔄 4. Terraform Remote State Setup

### 4.1 Tạo S3 Backend

```bash
# Tạo S3 bucket
aws s3 mb s3://uitgo-terraform-state --region ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket uitgo-terraform-state \
  --versioning-configuration Status=Enabled

# Tạo DynamoDB table cho locking
aws dynamodb create-table \
  --table-name uitgo-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

### 4.2 Initialize Terraform

```bash
cd infra/terraform/envs/dev

terraform init \
  -backend-config="bucket=uitgo-terraform-state" \
  -backend-config="key=uitgo/dev/terraform.tfstate" \
  -backend-config="region=ap-southeast-1" \
  -backend-config="dynamodb_table=uitgo-terraform-locks"
```

## ✅ 5. Verification Checklist

### Pre-deployment
- [ ] GitHub Secrets configured
- [ ] SealedSecrets controller running
- [ ] ArgoCD installed and applications created
- [ ] Sealed secrets generated and committed
- [ ] Terraform state migrated to S3

### Test the pipeline
```bash
# Make a small change to backend
echo "// test" >> backend/cmd/server/main.go

# Commit and push
git add .
git commit -m "test: verify e2e pipeline"
git push origin dev
```

### Monitor deployment
1. GitHub Actions → Watch `Backend CI/CD` workflow
2. ArgoCD UI → Watch `uitgo-dev` application sync
3. kubectl → `kubectl -n uitgo get pods -w`

## 📊 6. Pipeline Flow Summary

| Branch | CI Jobs | Deploy Method | Verification |
|--------|---------|---------------|--------------|
| `dev` | test → build → scan → manifests | ArgoCD auto-sync | verify-deployment job |
| `main` | test → build → scan → manifests | ArgoCD auto-sync | verify-deployment job |
| PR | test → validate | None | PR checks |

## 🆘 Troubleshooting

### ArgoCD không sync
```bash
# Check application status
argocd app get uitgo-dev

# Force sync
argocd app sync uitgo-dev

# Check events
kubectl -n uitgo get events --sort-by='.lastTimestamp'
```

### SealedSecrets không decrypt
```bash
# Check controller logs
kubectl -n sealed-secrets logs -l name=sealed-secrets-controller

# Verify cert matches
kubeseal --fetch-cert | diff - pub-sealed-secrets.pem
```

### Terraform state lock
```bash
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

## 📁 Files Changed

| File | Purpose |
|------|---------|
| `k8s/argocd/uitgo-staging.yaml` | Enabled auto-sync |
| `k8s/base/sealed-secrets-controller.yaml` | SealedSecrets CRD + controller |
| `k8s/base/kustomization.yaml` | Include sealed-secrets-controller |
| `k8s/overlays/dev/sealed-secrets.yaml` | Dev environment sealed secrets |
| `k8s/overlays/staging/sealed-secrets.yaml` | Staging environment sealed secrets |
| `k8s/overlays/*/kustomization.yaml` | Include sealed-secrets.yaml |
| `.github/workflows/seal-secrets.yml` | Workflow to seal secrets from GitHub Secrets |
| `.github/workflows/terraform.yml` | Terraform plan/apply CI |
| `.github/workflows/backend-cicd.yml` | Added verify-deployment stage |
| `.github/workflows/deploy.yml` | Fixed .env.staging generation |
| `infra/terraform/envs/dev/backend.tf` | S3 remote state config |
