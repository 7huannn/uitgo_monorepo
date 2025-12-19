#!/bin/bash
# UITGo Kubernetes Development Helper Script
# Usage: ./scripts/k8s-dev.sh [start|stop|status|logs|forward]

set -e

NAMESPACE="uitgo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_k3s() {
    if ! kubectl cluster-info &>/dev/null; then
        log_error "k3s cluster not running. Start with: sudo systemctl start k3s"
        exit 1
    fi
}

cmd_start() {
    log_info "Starting UITGo on Kubernetes..."
    check_k3s
    
    # Ensure local registry is running
    if ! docker ps | grep -q "registry:2"; then
        log_info "Starting local registry..."
        docker run -d -p 5000:5000 --name registry registry:2 2>/dev/null || true
    fi
    
    # Apply manifests
    log_info "Applying Kubernetes manifests..."
    kubectl apply -k "$PROJECT_ROOT/k8s/overlays/dev"
    
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=user-service -n $NAMESPACE --timeout=120s
    kubectl wait --for=condition=ready pod -l app=trip-service -n $NAMESPACE --timeout=120s
    kubectl wait --for=condition=ready pod -l app=driver-service -n $NAMESPACE --timeout=120s
    
    log_info " UITGo is running!"
    cmd_status
}

cmd_stop() {
    log_info "Stopping UITGo..."
    kubectl delete -k "$PROJECT_ROOT/k8s/overlays/dev" --ignore-not-found
    log_info " UITGo stopped"
}

cmd_status() {
    check_k3s
    echo ""
    log_info "=== Pod Status ==="
    kubectl get pods -n $NAMESPACE
    echo ""
    log_info "=== Services ==="
    kubectl get svc -n $NAMESPACE
    echo ""
    log_info "=== Resource Usage ==="
    kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics not available"
}

cmd_logs() {
    local service="${1:-user-service}"
    check_k3s
    log_info "Streaming logs for $service..."
    kubectl logs -f -n $NAMESPACE deployment/$service
}

cmd_forward() {
    check_k3s
    log_info "Setting up port forwarding..."
    
    # Kill existing port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 1
    
    # Start port forwards in background
    kubectl port-forward -n $NAMESPACE svc/user-service 8081:8081 &
    kubectl port-forward -n $NAMESPACE svc/trip-service 8082:8082 &
    kubectl port-forward -n $NAMESPACE svc/driver-service 8083:8083 &
    
    # Monitoring & ArgoCD
    kubectl port-forward -n monitoring svc/grafana 3000:3000 2>/dev/null &
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 2>/dev/null &
    kubectl port-forward -n argocd svc/argocd-server 8443:443 2>/dev/null &
    
    sleep 2
    log_info " Port forwarding active:"
    echo "  • User Service:   http://localhost:8081"
    echo "  • Trip Service:   http://localhost:8082"  
    echo "  • Driver Service: http://localhost:8083"
    echo ""
    echo "  • Grafana:        http://localhost:3000  (admin/uitgo)"
    echo "  • Prometheus:     http://localhost:9090"
    echo "  • ArgoCD:         https://localhost:8443 (admin/LFLCTz5yGEog1k5X)"
    echo ""
    log_info "Press Ctrl+C to stop port forwarding"
    wait
}

cmd_build() {
    log_info "Building and pushing images to local registry..."
    cd "$PROJECT_ROOT"
    
    for svc in user_service trip_service driver_service; do
        svc_name=$(echo $svc | tr '_' '-')
        log_info "Building $svc_name..."
        docker build -f backend/${svc}/Dockerfile -t localhost:5000/${svc_name}:dev .
        docker push localhost:5000/${svc_name}:dev
    done
    
    log_info " All images built and pushed"
}

cmd_restart() {
    local service="${1:-all}"
    check_k3s
    
    if [ "$service" = "all" ]; then
        log_info "Restarting all services..."
        kubectl rollout restart deployment -n $NAMESPACE user-service trip-service driver-service
    else
        log_info "Restarting $service..."
        kubectl rollout restart deployment -n $NAMESPACE $service
    fi
    
    log_info " Restart initiated"
}

cmd_help() {
    echo "UITGo Kubernetes Development Helper"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start     Start UITGo on k3s"
    echo "  stop      Stop UITGo"
    echo "  status    Show pod/service status"
    echo "  logs      Stream logs (default: user-service)"
    echo "  forward   Setup port forwarding"
    echo "  build     Build and push images"
    echo "  restart   Restart services"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs trip-service"
    echo "  $0 restart user-service"
}

# Main
case "${1:-help}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    status)  cmd_status ;;
    logs)    cmd_logs "$2" ;;
    forward) cmd_forward ;;
    build)   cmd_build ;;
    restart) cmd_restart "$2" ;;
    *)       cmd_help ;;
esac
