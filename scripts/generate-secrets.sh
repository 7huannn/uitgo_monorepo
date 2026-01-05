#!/bin/bash
# Generate all production secrets for UITGo
# Run this script and save output securely (password manager, vault, etc.)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  UITGo Production Secrets Generator${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}⚠️  SAVE THESE SECURELY! Do NOT commit to git!${NC}"
echo ""

echo "# =============================================="
echo "# Database Credentials"
echo "# =============================================="
echo "POSTGRES_USER=uitgo"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
echo ""

echo "# =============================================="
echo "# JWT & Authentication"
echo "# =============================================="
echo "JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=')"
echo "REFRESH_TOKEN_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '/+=')"
echo ""

echo "# =============================================="
echo "# Internal Service Communication"
echo "# =============================================="
echo "INTERNAL_API_KEY=$(openssl rand -base64 32 | tr -d '/+=')"
echo ""

echo "# =============================================="
echo "# Redis"
echo "# =============================================="
echo "REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
echo ""

echo "# =============================================="
echo "# Admin User (Development Only)"
echo "# =============================================="
echo "ADMIN_EMAIL=admin@uitgo.com"
echo "ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=')"
echo "ADMIN_NAME=UITGo Admin"
echo ""

echo "# =============================================="
echo "# Grafana"
echo "# =============================================="
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=')"
echo ""

echo "# =============================================="
echo "# TLS (generate with cert-manager or manually)"
echo "# =============================================="
echo "# For local testing, use mkcert:"
echo "# mkcert -install"
echo "# mkcert uitgo.local '*.uitgo.local'"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Done! Copy and save these secrets securely.${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
