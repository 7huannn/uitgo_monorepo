#!/bin/bash
# =============================================================================
#  UITGo DevOps Demo - Báo cáo môn học
# =============================================================================
# Chạy: ./scripts/demo-presentation.sh
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear

pause() {
    echo ""
    echo -e "${YELLOW}⏸  Nhấn Enter để tiếp tục...${NC}"
    read
}

section() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}$1${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# SLIDE 1: Giới thiệu
# =============================================================================
section "UITGO - Hệ thống đặt xe công nghệ"

cat << 'EOF'
 TỔNG QUAN DỰ ÁN:
   • Ứng dụng đặt xe giống Grab/Be
   • Backend: Go microservices (3 services)
   • Frontend: Flutter (3 apps: rider, driver, admin)
   • Database: PostgreSQL (database-per-service)
   • Cache: Redis

  DEVOPS STACK:
   • Container Orchestration: Kubernetes (k3s)
   • GitOps: ArgoCD
   • Monitoring: Prometheus + Grafana
   • CI/CD: GitHub Actions
   • IaC: Kustomize

EOF
pause

# =============================================================================
# SLIDE 2: Kiểm tra Cluster
# =============================================================================
section " DEMO 1: Kubernetes Cluster"

echo -e "${CYAN}1.1 Kiểm tra nodes:${NC}"
kubectl get nodes
echo ""

echo -e "${CYAN}1.2 Namespaces:${NC}"
kubectl get namespaces | grep -E "uitgo|monitoring|argocd"
echo ""

pause

# =============================================================================
# SLIDE 3: Application Pods
# =============================================================================
section " DEMO 2: Application Services"

echo -e "${CYAN}2.1 Pods trong namespace 'uitgo':${NC}"
kubectl get pods -n uitgo -o wide
echo ""

echo -e "${CYAN}2.2 Services:${NC}"
kubectl get svc -n uitgo
echo ""

echo -e "${CYAN}2.3 Resource Usage:${NC}"
kubectl top pods -n uitgo 2>/dev/null || echo "(metrics chưa available)"
echo ""

pause

# =============================================================================
# SLIDE 4: Test API
# =============================================================================
section "DEMO 3: API Testing"

echo -e "${CYAN}3.1 Health Check các services:${NC}"
echo -n "   User Service:   "; curl -s localhost:8081/health 2>/dev/null || echo "  Cần chạy port-forward"
echo -n "   Trip Service:   "; curl -s localhost:8082/health 2>/dev/null || echo "  Cần chạy port-forward"  
echo -n "   Driver Service: "; curl -s localhost:8083/health 2>/dev/null || echo "  Cần chạy port-forward"
echo ""

echo -e "${CYAN}3.2 Test đăng ký user:${NC}"
REGISTER_RESP=$(curl -s -X POST localhost:8081/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"+8490$(date +%s | tail -c 8)\",\"password\":\"Demo@123\",\"name\":\"Demo User\",\"email\":\"demo$(date +%s)@test.com\",\"role\":\"rider\"}" 2>/dev/null)
  
if [ -n "$REGISTER_RESP" ]; then
    echo "$REGISTER_RESP" | jq -r '{id, email, name, role}' 2>/dev/null || echo "$REGISTER_RESP"
else
    echo " Cần chạy port-forward trước"
fi
echo ""

pause

# =============================================================================
# SLIDE 5: Monitoring
# =============================================================================
section " DEMO 4: Monitoring Stack"

echo -e "${CYAN}4.1 Monitoring Pods:${NC}"
kubectl get pods -n monitoring
echo ""

echo -e "${CYAN}4.2 Prometheus targets:${NC}"
curl -s localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null | head -5 || echo "⚠️  Cần port-forward Prometheus"
echo ""

echo -e "${CYAN}4.3 Access URLs:${NC}"
echo "   • Prometheus: http://localhost:9090"
echo "   • Grafana:    http://localhost:3000 (admin/uitgo)"
echo ""

pause

# =============================================================================
# SLIDE 6: ArgoCD GitOps
# =============================================================================
section " DEMO 5: GitOps với ArgoCD"

echo -e "${CYAN}5.1 ArgoCD Pods:${NC}"
kubectl get pods -n argocd | head -8
echo ""

echo -e "${CYAN}5.2 Applications:${NC}"
kubectl get applications -n argocd
echo ""

echo -e "${CYAN}5.3 Application Details:${NC}"
kubectl get application uitgo-dev -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null && echo " (Sync Status)"
kubectl get application uitgo-dev -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null && echo " (Health Status)"
echo ""

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
echo -e "${CYAN}5.4 ArgoCD Access:${NC}"
echo "   • URL:      https://localhost:8443"
echo "   • Username: admin"
echo "   • Password: $ARGOCD_PASS"
echo ""

pause

# =============================================================================
# SLIDE 7: CI/CD Pipeline
# =============================================================================
section "  DEMO 6: CI/CD Pipeline"

echo -e "${CYAN}6.1 GitHub Actions Workflow:${NC}"
cat << 'EOF'
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │   Commit    │───▶│    Test     │───▶│    Build    │───▶│    Push     │
   │   Code      │    │   & Lint    │    │   Image     │    │  Registry   │
   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                   │
                                                                   ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │   Live!     │◀───│   Deploy    │◀───│   ArgoCD    │◀───│   Detect    │
   │             │    │   to K8s    │    │   Sync      │    │   Changes   │
   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
EOF
echo ""

echo -e "${CYAN}6.2 Workflow file:${NC}"
echo "   .github/workflows/backend-cicd.yml"
echo ""

pause

# =============================================================================
# SLIDE 8: Live Demo - Code Change
# =============================================================================
section " DEMO 7: Live Deployment"

echo -e "${CYAN}Quy trình deploy sau khi sửa code:${NC}"
echo ""
echo "   1. Sửa code backend"
echo "   2. Build image mới:"
echo -e "      ${GREEN}./scripts/k8s-dev.sh build${NC}"
echo ""
echo "   3. Restart services:"
echo -e "      ${GREEN}./scripts/k8s-dev.sh restart${NC}"
echo ""
echo "   4. Kiểm tra:"
echo -e "      ${GREEN}./scripts/k8s-dev.sh status${NC}"
echo ""

pause

# =============================================================================
# SLIDE 9: Kiến trúc tổng quan
# =============================================================================
section "  KIẾN TRÚC HỆ THỐNG"

cat << 'EOF'

                            ┌──────────────────┐
                            │   GitHub Repo    │
                            │  (Source Code)   │
                            └────────┬─────────┘
                                     │ Push
                                     ▼
                            ┌──────────────────┐
                            │  GitHub Actions  │
                            │   (CI Pipeline)  │
                            └────────┬─────────┘
                                     │ Build & Push
                                     ▼
    ┌──────────────────────────────────────────────────────────────┐
    │                    Kubernetes (k3s)                          │
    │  ┌─────────────────────────────────────────────────────────┐ │
    │  │                    ArgoCD (GitOps)                      │ │
    │  └─────────────────────────────────────────────────────────┘ │
    │                              │                               │
    │              ┌───────────────┼───────────────┐               │
    │              ▼               ▼               ▼               │
    │     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐      │
    │     │ user-service │ │ trip-service │ │driver-service│      │
    │     │    :8081     │ │    :8082     │ │    :8083     │      │
    │     └──────┬───────┘ └──────┬───────┘ └──────┬───────┘      │
    │            │                │                │               │
    │     ┌──────▼───────┐ ┌──────▼───────┐ ┌──────▼───────┐      │
    │     │   user-db    │ │   trip-db    │ │  driver-db   │      │
    │     │ (PostgreSQL) │ │ (PostgreSQL) │ │ (PostgreSQL) │      │
    │     └──────────────┘ └──────────────┘ └──────────────┘      │
    │                              │                               │
    │                       ┌──────▼───────┐                       │
    │                       │    Redis     │                       │
    │                       │  (Cache/MQ)  │                       │
    │                       └──────────────┘                       │
    │  ┌─────────────────────────────────────────────────────────┐ │
    │  │              Monitoring (Prometheus + Grafana)          │ │
    │  └─────────────────────────────────────────────────────────┘ │
    └──────────────────────────────────────────────────────────────┘

EOF

pause

# =============================================================================
# SLIDE 10: Tổng kết
# =============================================================================
section " TỔNG KẾT"

cat << 'EOF'
 NHỮNG GÌ ĐÃ TRIỂN KHAI:

    Kubernetes với k3s (lightweight, production-ready)
    3 Microservices + 3 Databases + Redis
    GitOps với ArgoCD (auto-sync từ Git)
    Monitoring với Prometheus + Grafana
    CI/CD Pipeline với GitHub Actions
    Infrastructure as Code với Kustomize

 CẤU TRÚC THƯ MỤC:

   k8s/
   ├── base/           # Base manifests
   ├── overlays/       # Environment configs (dev/staging)
   ├── monitoring/     # Prometheus, Grafana, Loki
   └── argocd/         # GitOps applications

 WORKFLOW HÀNG NGÀY:

   ./scripts/k8s-dev.sh status    # Kiểm tra
   ./scripts/k8s-dev.sh forward   # Port forward
   ./scripts/k8s-dev.sh build     # Build images
   ./scripts/k8s-dev.sh restart   # Restart services

EOF

echo -e "${GREEN}${BOLD}Demo hoàn tất! 🎉${NC}"
echo ""
