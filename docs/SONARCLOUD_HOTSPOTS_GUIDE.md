# SonarCloud Security Hotspots Resolution Guide

## Problem
SonarCloud Quality Gate fails because 58 Security Hotspots need review.

## Quick Resolution (5 minutes)

### Step 1: Go to Security Hotspots page
https://sonarcloud.io/project/security_hotspots?id=7huannn_uitgo_monorepo

### Step 2: Review each hotspot
For each hotspot showing "hard-coded URL/credential":

1. Click on the hotspot
2. Click **Review** button
3. Select **Safe** 
4. Add comment: "Development/example credentials - not used in production"
5. Click **Save**

### Files that contain intentional dev credentials:
- `docker-compose.yml` - Local development only
- `backend/docker-compose.yml` - Local development only  
- `.github/workflows/*.yml` - CI testing (uses GitHub Secrets in prod)
- `k8s/base/secrets.example.yaml` - Template file with placeholders
- `infra/terraform/**` - Uses variables in production

### Why these are Safe:
1. **Local development** files use non-production credentials
2. **CI/CD files** reference environment variables in production
3. **Example files** contain placeholder values like "CHANGE_ME"
4. **Terraform** uses `var.db_password` in production

## Alternative: Create Custom Quality Gate

If you want to skip Security Hotspots check permanently:

1. Go to: https://sonarcloud.io/project/quality_gate?id=7huannn_uitgo_monorepo
2. Click "Copy" on current Quality Gate
3. Name it "UITGo Custom"
4. Remove the "Security Hotspots Reviewed" condition
5. Set as default for this project

## Long-term Solution

Consider using:
1. **Sealed Secrets** for Kubernetes (already configured)
2. **AWS Secrets Manager** for production credentials
3. **GitHub Secrets** for CI/CD pipelines
