#!/bin/bash
# =============================================================================
# UITGo DevOps - Hướng dẫn chạy từng bước
# =============================================================================
# 
# Chạy file này để xem hướng dẫn: ./scripts/RUN_GUIDE.sh
# Hoặc copy từng lệnh để chạy thủ công
#
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

print_cmd() {
    echo -e "${GREEN}▶ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# =============================================================================
# PHASE 0: Kiểm tra prerequisites
# =============================================================================
print_step "PHASE 0: Kiểm tra Prerequisites"

echo "Kiểm tra các tools đã cài đặt:"
echo ""

check_tool() {
    if command -v $1 &> /dev/null; then
        echo -e "   $1: $(which $1)"
    else
        echo -e "   $1: Chưa cài đặt"
    fi
}

check_tool docker
check_tool kubectl
check_tool helm
check_tool k3s

echo ""
echo "Kiểm tra Kubernetes cluster:"
kubectl get nodes 2>/dev/null && echo -e "   Cluster đang chạy" || echo -e "   Cluster không kết nối được"

# =============================================================================
# PHASE 1: Setup Infrastructure
# =============================================================================
print_step "PHASE 1: Setup Infrastructure"

cat << 'COMMANDS'
# 1.1 Khởi động Local Docker Registry (nếu chưa có)
docker ps | grep registry || docker run -d --name registry --restart=always -p 5000:5000 registry:2

# 1.2 Cấu hình k3s để sử dụng local registry (cần sudo)
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml > /dev/null << 'EOF'
mirrors:
  "localhost:5000":
    endpoint:
      - "http://localhost:5000"
EOF

# 1.3 Restart k3s để áp dụng config mới
sudo systemctl restart k3s

# 1.4 Đợi k3s sẵn sàng
sleep 10
kubectl get nodes
COMMANDS

# =============================================================================
# PHASE 2: Build Docker Images
# =============================================================================
print_step "PHASE 2: Build Docker Images"

cat << 'COMMANDS'
# Từ thư mục root của project
cd ~/Workspace/uitgo_monorepo

# 2.1 Build user-service
docker build -t localhost:5000/uitgo/user-service:dev -f backend/user_service/Dockerfile .

# 2.2 Build trip-service
docker build -t localhost:5000/uitgo/trip-service:dev -f backend/trip_service/Dockerfile .

# 2.3 Build driver-service
docker build -t localhost:5000/uitgo/driver-service:dev -f backend/driver_service/Dockerfile .

# 2.4 Push tất cả images lên local registry
docker push localhost:5000/uitgo/user-service:dev
docker push localhost:5000/uitgo/trip-service:dev
docker push localhost:5000/uitgo/driver-service:dev

# Hoặc dùng Makefile:
make k8s-build
COMMANDS

# =============================================================================
# PHASE 3: Deploy to Kubernetes
# =============================================================================
print_step "PHASE 3: Deploy to Kubernetes"

cat << 'COMMANDS'
# 3.1 Tạo namespace trước
kubectl apply -f k8s/base/namespace.yaml

# 3.2 Deploy toàn bộ stack với Kustomize (dev overlay)
kubectl apply -k k8s/overlays/dev

# 3.3 Kiểm tra pods
kubectl get pods -n uitgo -w

# Hoặc dùng Makefile:
make k8s-deploy
COMMANDS

# =============================================================================
# PHASE 4: Deploy Monitoring Stack
# =============================================================================
print_step "PHASE 4: Deploy Monitoring Stack"

cat << 'COMMANDS'
# 4.1 Deploy Prometheus + Grafana + Loki
kubectl apply -k k8s/monitoring

# 4.2 Kiểm tra pods monitoring
kubectl get pods -n monitoring

# Hoặc dùng Makefile:
make k8s-monitoring
COMMANDS

# =============================================================================
# PHASE 5: Setup ArgoCD (GitOps)
# =============================================================================
print_step "PHASE 5: Setup ArgoCD (GitOps) - Optional"

cat << 'COMMANDS'
# 5.1 Tạo namespace ArgoCD
kubectl create namespace argocd

# 5.2 Cài đặt ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5.3 Đợi ArgoCD sẵn sàng
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 5.4 Lấy password admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# 5.5 Expose ArgoCD UI
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# 5.6 Lấy port để truy cập
kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}'

# 5.7 Apply ArgoCD applications
kubectl apply -f k8s/argocd/project.yaml
kubectl apply -f k8s/argocd/uitgo-dev.yaml
COMMANDS

# =============================================================================
# PHASE 6: Truy cập Services
# =============================================================================
print_step "PHASE 6: Truy cập Services"

cat << 'COMMANDS'
# 6.1 Port forward để truy cập local

# API Gateway (qua user-service tạm thời)
kubectl port-forward svc/user-service -n uitgo 8081:8081 &

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000 &

# Prometheus
kubectl port-forward svc/prometheus -n monitoring 9090:9090 &

# Hoặc dùng Makefile:
make k8s-port-forward

# 6.2 Endpoints sau khi port-forward:
# - User Service: http://localhost:8081
# - Trip Service: http://localhost:8082
# - Driver Service: http://localhost:8083
# - Grafana: http://localhost:3000 (admin/uitgo)
# - Prometheus: http://localhost:9090
COMMANDS

# =============================================================================
# QUICK COMMANDS (Makefile)
# =============================================================================
print_step "QUICK COMMANDS (Makefile)"

cat << 'COMMANDS'
# Tất cả commands có sẵn trong Makefile:

make k8s-build          # Build và push Docker images
make k8s-deploy         # Deploy app lên Kubernetes
make k8s-monitoring     # Deploy monitoring stack
make k8s-status         # Xem trạng thái cluster
make k8s-logs-user      # Xem logs user-service
make k8s-logs-trip      # Xem logs trip-service
make k8s-logs-driver    # Xem logs driver-service
make k8s-port-forward   # Mở port forward cho tất cả services
make k8s-clean          # Xóa tất cả resources
make k8s-restart        # Restart tất cả deployments
make argocd-sync        # Sync ArgoCD applications
make argocd-status      # Xem trạng thái ArgoCD
make ci-local           # Chạy CI locally với Act
make validate-manifests # Validate K8s manifests
COMMANDS

# =============================================================================
# TROUBLESHOOTING
# =============================================================================
print_step "TROUBLESHOOTING"

cat << 'COMMANDS'
# Xem logs của pod bị lỗi
kubectl logs -n uitgo <pod-name>

# Describe pod để xem events
kubectl describe pod -n uitgo <pod-name>

# Xem tất cả events trong namespace
kubectl get events -n uitgo --sort-by='.lastTimestamp'

# Restart một deployment
kubectl rollout restart deployment/user-service -n uitgo

# Xóa và deploy lại
make k8s-clean
make k8s-deploy

# Kiểm tra images trong local registry
curl http://localhost:5000/v2/_catalog
COMMANDS

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Hướng dẫn hoàn tất! Chạy từng bước theo thứ tự trên.${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
