#!/bin/bash
# UITGo Local DevOps Environment Setup Script
# This script sets up a complete local Kubernetes environment with:
# - k3s (lightweight Kubernetes)
# - ArgoCD (GitOps)
# - Monitoring stack (Prometheus, Grafana, Loki)
# - Local container registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker is installed: $(docker --version)"
    else
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    # Check curl
    if command -v curl &> /dev/null; then
        print_success "curl is installed"
    else
        print_error "curl is not installed. Please install curl."
        exit 1
    fi
    
    # Check available memory
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -ge 8 ]; then
        print_success "Sufficient memory: ${total_mem}GB available"
    else
        print_warning "Low memory: ${total_mem}GB. Recommended: 8GB+"
    fi
}

# Install k3s
install_k3s() {
    print_header "Installing k3s"
    
    if command -v k3s &> /dev/null; then
        print_warning "k3s is already installed"
        k3s --version
    else
        echo "Installing k3s (lightweight Kubernetes)..."
        curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
        
        # Wait for k3s to be ready
        echo "Waiting for k3s to start..."
        sleep 10
        
        # Check k3s status
        sudo systemctl status k3s --no-pager || true
        print_success "k3s installed successfully"
    fi
    
    # Configure kubectl
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config
    
    print_success "kubectl configured"
    
    # Verify cluster
    kubectl cluster-info
    kubectl get nodes
}

# Install Helm
install_helm() {
    print_header "Installing Helm"
    
    if command -v helm &> /dev/null; then
        print_warning "Helm is already installed"
        helm version
    else
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        print_success "Helm installed successfully"
    fi
}

# Setup local container registry
setup_local_registry() {
    print_header "Setting up Local Container Registry"
    
    # Check if registry is already running
    if docker ps | grep -q "registry:2"; then
        print_warning "Local registry is already running"
    else
        # Start local registry
        docker run -d \
            --name registry \
            --restart=always \
            -p 5000:5000 \
            registry:2
        print_success "Local registry started on localhost:5000"
    fi
    
    # Add registry to k3s registries.yaml
    sudo mkdir -p /etc/rancher/k3s
    if [ ! -f /etc/rancher/k3s/registries.yaml ]; then
        sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<EOF
mirrors:
  "localhost:5000":
    endpoint:
      - "http://localhost:5000"
EOF
        print_success "Registry configured for k3s"
        print_warning "Restart k3s for registry changes to take effect: sudo systemctl restart k3s"
    fi
}

# Install ArgoCD
install_argocd() {
    print_header "Installing ArgoCD"
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get initial admin password
    echo ""
    print_success "ArgoCD installed successfully"
    echo ""
    echo "ArgoCD initial admin password:"
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo ""
    echo ""
    
    # Patch ArgoCD service to NodePort for local access
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
    print_success "ArgoCD UI available at: https://localhost:${ARGOCD_PORT}"
}

# Install ArgoCD CLI
install_argocd_cli() {
    print_header "Installing ArgoCD CLI"
    
    if command -v argocd &> /dev/null; then
        print_warning "ArgoCD CLI is already installed"
    else
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        print_success "ArgoCD CLI installed"
    fi
}

# Install Act (Local GitHub Actions runner)
install_act() {
    print_header "Installing Act (Local GitHub Actions runner)"
    
    if command -v act &> /dev/null; then
        print_warning "Act is already installed"
        act --version
    else
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
        print_success "Act installed successfully"
    fi
}

# Build and push UITGo images to local registry
build_images() {
    print_header "Building UITGo Docker Images"
    
    cd "$(dirname "$0")/.."
    
    # Build user-service
    echo "Building user-service..."
    docker build -t localhost:5000/uitgo/user-service:dev -f backend/user_service/Dockerfile .
    docker push localhost:5000/uitgo/user-service:dev
    print_success "user-service built and pushed"
    
    # Build trip-service
    echo "Building trip-service..."
    docker build -t localhost:5000/uitgo/trip-service:dev -f backend/trip_service/Dockerfile .
    docker push localhost:5000/uitgo/trip-service:dev
    print_success "trip-service built and pushed"
    
    # Build driver-service
    echo "Building driver-service..."
    docker build -t localhost:5000/uitgo/driver-service:dev -f backend/driver_service/Dockerfile .
    docker push localhost:5000/uitgo/driver-service:dev
    print_success "driver-service built and pushed"
}

# Deploy UITGo to Kubernetes
deploy_uitgo() {
    print_header "Deploying UITGo to Kubernetes"
    
    cd "$(dirname "$0")/.."
    
    # Apply base manifests first for namespace
    kubectl apply -f k8s/base/namespace.yaml
    
    # Deploy using Kustomize (dev overlay)
    kubectl apply -k k8s/overlays/dev
    
    # Wait for deployments
    echo "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/user-service -n uitgo || true
    kubectl wait --for=condition=available --timeout=300s deployment/trip-service -n uitgo || true
    kubectl wait --for=condition=available --timeout=300s deployment/driver-service -n uitgo || true
    
    print_success "UITGo deployed successfully"
    
    # Show deployment status
    kubectl get pods -n uitgo
}

# Deploy monitoring stack
deploy_monitoring() {
    print_header "Deploying Monitoring Stack"
    
    cd "$(dirname "$0")/.."
    
    # Apply monitoring manifests
    kubectl apply -k k8s/monitoring
    
    # Wait for deployments
    echo "Waiting for monitoring stack..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring || true
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring || true
    kubectl wait --for=condition=available --timeout=300s deployment/loki -n monitoring || true
    
    print_success "Monitoring stack deployed"
    
    # Get Grafana NodePort
    kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "NodePort"}}'
    GRAFANA_PORT=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo ""
    print_success "Grafana available at: http://localhost:${GRAFANA_PORT}"
    echo "  Username: admin"
    echo "  Password: uitgo"
}

# Configure ArgoCD application
configure_argocd_app() {
    print_header "Configuring ArgoCD Application"
    
    cd "$(dirname "$0")/.."
    
    # Apply ArgoCD project and applications
    kubectl apply -f k8s/argocd/project.yaml
    kubectl apply -f k8s/argocd/uitgo-dev.yaml
    
    print_success "ArgoCD application configured"
    echo ""
    echo "ArgoCD will now automatically sync your k8s/overlays/dev directory"
}

# Add hosts entries
setup_hosts() {
    print_header "Setting up /etc/hosts entries"
    
    HOSTS_ENTRIES="127.0.0.1 uitgo.local grafana.uitgo.local argocd.uitgo.local"
    
    if grep -q "uitgo.local" /etc/hosts; then
        print_warning "Host entries already exist"
    else
        echo "Adding entries to /etc/hosts (requires sudo)..."
        echo "$HOSTS_ENTRIES" | sudo tee -a /etc/hosts
        print_success "Host entries added"
    fi
}

# Print summary
print_summary() {
    print_header "Setup Complete! 🎉"
    
    echo "Your local DevOps environment is ready:"
    echo ""
    echo "📦 Kubernetes (k3s)"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
    echo "🔄 ArgoCD (GitOps)"
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    echo "   URL: https://localhost:${ARGOCD_PORT}"
    echo "   Username: admin"
    echo "   Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d')"
    echo ""
    echo "📊 Grafana (Monitoring)"
    GRAFANA_PORT=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    echo "   URL: http://localhost:${GRAFANA_PORT}"
    echo "   Username: admin"
    echo "   Password: uitgo"
    echo ""
    echo "🚀 UITGo Application"
    echo "   kubectl get pods -n uitgo"
    echo "   API: http://uitgo.local (after adding to /etc/hosts)"
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Push changes to Git"
    echo "   2. ArgoCD will automatically sync"
    echo "   3. Monitor in Grafana"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       UITGo Local DevOps Environment Setup                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    case "${1:-full}" in
        prerequisites)
            check_prerequisites
            ;;
        k3s)
            check_prerequisites
            install_k3s
            ;;
        helm)
            install_helm
            ;;
        registry)
            setup_local_registry
            ;;
        argocd)
            install_argocd
            install_argocd_cli
            ;;
        act)
            install_act
            ;;
        build)
            build_images
            ;;
        deploy)
            deploy_uitgo
            ;;
        monitoring)
            deploy_monitoring
            ;;
        hosts)
            setup_hosts
            ;;
        full)
            check_prerequisites
            install_k3s
            install_helm
            setup_local_registry
            install_argocd
            install_argocd_cli
            install_act
            setup_hosts
            build_images
            deploy_uitgo
            deploy_monitoring
            configure_argocd_app
            print_summary
            ;;
        *)
            echo "Usage: $0 {full|prerequisites|k3s|helm|registry|argocd|act|build|deploy|monitoring|hosts}"
            echo ""
            echo "Commands:"
            echo "  full          - Run complete setup (default)"
            echo "  prerequisites - Check system requirements"
            echo "  k3s           - Install k3s only"
            echo "  helm          - Install Helm only"
            echo "  registry      - Setup local Docker registry"
            echo "  argocd        - Install ArgoCD"
            echo "  act           - Install Act (local GitHub Actions)"
            echo "  build         - Build and push Docker images"
            echo "  deploy        - Deploy UITGo to Kubernetes"
            echo "  monitoring    - Deploy monitoring stack"
            echo "  hosts         - Add entries to /etc/hosts"
            exit 1
            ;;
    esac
}

main "$@"
