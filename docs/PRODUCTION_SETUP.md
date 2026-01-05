# Production Deployment Setup Guide

Hướng dẫn này giúp bạn thiết lập UITGo cho production một cách an toàn.

## Mục lục

1. [Purge Secrets from Git History](#1-purge-secrets-from-git-history)
2. [AWS OIDC Provider Setup](#2-aws-oidc-provider-setup)
3. [GitHub Repository Secrets](#3-github-repository-secrets)
4. [Sealed Secrets Setup](#4-sealed-secrets-setup)
5. [Generate Production Secrets](#5-generate-production-secrets)

---

## 1. Purge Secrets from Git History

> ⚠️ **Bạn đã xóa IAM user/access key trên AWS - tốt!** Nhưng credentials vẫn còn trong git history.

### Option A: Sử dụng BFG (Recommended)

```bash
# Chạy script đã tạo sẵn
cd /home/thuan/Workspace/uitgo_monorepo
chmod +x scripts/purge-secrets.sh
./scripts/purge-secrets.sh

# Sau khi script chạy xong, force push
git push --force --all origin
git push --force --tags origin
```

### Option B: Manual với git filter-repo

```bash
# Install git-filter-repo
pip install git-filter-repo

# Backup repo
cp -r . ../uitgo_backup

# Remove sensitive files from all history
git filter-repo --invert-paths --path infra/terraform/envs/dev/terraform.tfvars
git filter-repo --invert-paths --path infra/terraform/envs/dev/terraform.tfstate
git filter-repo --invert-paths --path infra/terraform/envs/dev/terraform.tfstate.backup
git filter-repo --invert-paths --path k8s/base/secrets.yaml

# Force push
git push --force --all origin
```

### Sau khi purge

1. **Contact GitHub Support** để yêu cầu garbage collection ngay lập tức
2. Thông báo team members re-clone repository
3. Invalidate tất cả credentials đã leak (✅ bạn đã làm với AWS)

---

## 2. AWS OIDC Provider Setup

GitHub Actions sử dụng OIDC để authenticate với AWS thay vì static credentials.

### Step 2.1: Tạo OIDC Identity Provider trong AWS

```bash
# Sử dụng AWS CLI
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Hoặc qua AWS Console:
# IAM → Identity providers → Add provider
# - Provider type: OpenID Connect
# - Provider URL: https://token.actions.githubusercontent.com
# - Audience: sts.amazonaws.com
```

### Step 2.2: Tạo IAM Role cho GitHub Actions

Tạo file `github-actions-role.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:7huannn/uitgo_monorepo:*"
        }
      }
    }
  ]
}
```

```bash
# Tạo role
aws iam create-role \
  --role-name GitHubActions-UITGo \
  --assume-role-policy-document file://github-actions-role.json

# Attach policies cần thiết
aws iam attach-role-policy \
  --role-name GitHubActions-UITGo \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name GitHubActions-UITGo \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

aws iam attach-role-policy \
  --role-name GitHubActions-UITGo \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-role-policy \
  --role-name GitHubActions-UITGo \
  --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess

# Lấy Role ARN
aws iam get-role --role-name GitHubActions-UITGo --query 'Role.Arn' --output text
```

### Step 2.3: Tạo S3 Backend cho Terraform State

```bash
# Tạo S3 bucket cho state
aws s3api create-bucket \
  --bucket uitgo-terraform-state-YOUR_ACCOUNT_ID \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket uitgo-terraform-state-YOUR_ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket uitgo-terraform-state-YOUR_ACCOUNT_ID \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}}]
  }'

# Tạo DynamoDB table cho state locking
aws dynamodb create-table \
  --table-name uitgo-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

---

## 3. GitHub Repository Secrets

Vào GitHub repo → Settings → Secrets and variables → Actions → New repository secret

### Required Secrets

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `AWS_ROLE_ARN` | IAM Role ARN cho OIDC | `aws iam get-role --role-name GitHubActions-UITGo --query 'Role.Arn' --output text` |
| `TF_STATE_BUCKET` | S3 bucket name | `uitgo-terraform-state-YOUR_ACCOUNT_ID` |
| `TF_LOCK_TABLE` | DynamoDB table name | `uitgo-terraform-locks` |

### Optional Secrets (nếu dùng)

| Secret Name | Description |
|-------------|-------------|
| `GHCR_TOKEN` | Personal Access Token cho GitHub Container Registry |
| `SONAR_TOKEN` | Token cho SonarCloud |
| `SENTRY_DSN` | Sentry DSN cho error tracking |

---

## 4. Sealed Secrets Setup

Sealed Secrets cho phép encrypt secrets để commit vào Git an toàn.

### Step 4.1: Install Sealed Secrets Controller

```bash
# Add helm repo
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# Install controller
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set fullnameOverride=sealed-secrets-controller
```

### Step 4.2: Install kubeseal CLI

```bash
# Linux
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep tag_name | cut -d '"' -f 4 | cut -d 'v' -f 2)
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# macOS
brew install kubeseal
```

### Step 4.3: Create Sealed Secrets

```bash
# 1. Tạo secret file (KHÔNG commit file này!)
cat > /tmp/uitgo-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: uitgo-secrets
  namespace: uitgo
type: Opaque
stringData:
  POSTGRES_USER: "uitgo"
  POSTGRES_PASSWORD: "$(openssl rand -base64 24)"
  JWT_SECRET: "$(openssl rand -base64 32)"
  REFRESH_TOKEN_ENCRYPTION_KEY: "$(openssl rand -base64 32)"
  INTERNAL_API_KEY: "$(openssl rand -base64 32)"
  REDIS_PASSWORD: "$(openssl rand -base64 24)"
EOF

# 2. Seal the secret
kubeseal --format yaml < /tmp/uitgo-secrets.yaml > k8s/overlays/dev/sealed-secrets.yaml

# 3. Xóa file tạm
rm /tmp/uitgo-secrets.yaml

# 4. Commit sealed secret (an toàn!)
git add k8s/overlays/dev/sealed-secrets.yaml
git commit -m "chore: add sealed secrets for dev environment"
```

### Step 4.4: Tạo Grafana Secret

```bash
# Tạo secret cho Grafana
cat > /tmp/grafana-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secrets
  namespace: monitoring
type: Opaque
stringData:
  admin-password: "$(openssl rand -base64 24)"
EOF

# Seal it
kubeseal --format yaml < /tmp/grafana-secrets.yaml > k8s/monitoring/sealed-grafana-secrets.yaml

# Cleanup
rm /tmp/grafana-secrets.yaml
```

---

## 5. Generate Production Secrets

Script để generate tất cả secrets cần thiết:

```bash
#!/bin/bash
# scripts/generate-secrets.sh

echo "=== UITGo Production Secrets ==="
echo "Save these securely! Do NOT commit to git!"
echo ""

echo "# Database"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24)"
echo ""

echo "# JWT"
echo "JWT_SECRET=$(openssl rand -base64 32)"
echo "REFRESH_TOKEN_ENCRYPTION_KEY=$(openssl rand -base64 32)"
echo ""

echo "# Internal API"
echo "INTERNAL_API_KEY=$(openssl rand -base64 32)"
echo ""

echo "# Redis"
echo "REDIS_PASSWORD=$(openssl rand -base64 24)"
echo ""

echo "# Admin (chỉ dùng cho dev)"
echo "ADMIN_PASSWORD=$(openssl rand -base64 16)"
echo ""

echo "# Grafana"
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)"
```

---

## Quick Setup Summary

```bash
# 1. Purge git history
./scripts/purge-secrets.sh
git push --force --all origin

# 2. Setup AWS OIDC (one-time)
# → Tạo OIDC Provider trong AWS IAM
# → Tạo IAM Role với trust policy cho GitHub
# → Tạo S3 bucket và DynamoDB table

# 3. Configure GitHub Secrets
# → AWS_ROLE_ARN
# → TF_STATE_BUCKET
# → TF_LOCK_TABLE

# 4. Setup Sealed Secrets in cluster
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# 5. Create and seal secrets
kubeseal --format yaml < secrets.yaml > sealed-secrets.yaml
```

---

## Troubleshooting

### OIDC Authentication fails
```
Error: Could not assume role with OIDC
```
- Kiểm tra trust policy của IAM Role
- Verify repo name trong Condition matches exactly
- Check GitHub Actions permissions: `id-token: write`

### Sealed Secrets not decrypting
```
Error: no key could decrypt secret
```
- Controller có thể đã được reinstall (new key)
- Re-seal tất cả secrets với key mới:
  ```bash
  kubeseal --fetch-cert > sealed-secrets-cert.pem
  kubeseal --cert sealed-secrets-cert.pem < secret.yaml > sealed-secret.yaml
  ```

### Terraform state locked
```
Error: Error acquiring the state lock
```
- Check DynamoDB table có entry lock không:
  ```bash
  aws dynamodb scan --table-name uitgo-terraform-locks
  ```
- Force unlock nếu cần:
  ```bash
  terraform force-unlock LOCK_ID
  ```
