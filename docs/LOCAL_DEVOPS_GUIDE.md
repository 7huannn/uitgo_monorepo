# UITGo Local DevOps Guide

This guide explains how to set up and use a production-grade DevOps workflow for UITGo, running entirely on your local machine.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Detailed Setup Guide](#detailed-setup-guide)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [GitOps with ArgoCD](#gitops-with-argocd)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Monitoring & Observability](#monitoring--observability)
9. [Common Operations](#common-operations)
10. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LOCAL DEVOPS ENVIRONMENT                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Developer Workflow:                                                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │  Code Change │───▶│   Git Push   │───▶│   CI/CD      │                  │
│  │              │    │              │    │  (GH Actions)│                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│                                                  │                          │
│                                                  ▼                          │
│                      ┌───────────────────────────────────────┐              │
│                      │           k3s Kubernetes              │              │
│                      │  ┌─────────────────────────────────┐  │              │
│                      │  │    ArgoCD (GitOps Controller)   │  │              │
│                      │  │    Watches: k8s/overlays/*      │  │              │
│                      │  └─────────────────────────────────┘  │              │
│                      │                  │                    │              │
│                      │   ┌──────────────┴──────────────┐     │              │
│                      │   ▼              ▼              ▼     │              │
│                      │ ┌────────┐  ┌────────┐  ┌────────┐   │              │
│                      │ │  user  │  │  trip  │  │ driver │   │              │
│                      │ │service │  │service │  │service │   │              │
│                      │ └────────┘  └────────┘  └────────┘   │              │
│                      │       │          │           │        │              │
│                      │       └──────────┼───────────┘        │              │
│                      │                  ▼                    │              │
│                      │         ┌───────────────┐             │              │
│                      │         │ Redis + 3×PG  │             │              │
│                      │         └───────────────┘             │              │
│                      └───────────────────────────────────────┘              │
│                                         │                                   │
│                      ┌──────────────────┴──────────────────┐                │
│                      │         Observability Stack         │                │
│                      │   Prometheus │ Grafana │ Loki       │                │
│                      └─────────────────────────────────────┘                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Container Orchestration** | Run microservices | k3s (lightweight Kubernetes) |
| **GitOps** | Declarative deployments | ArgoCD |
| **CI/CD** | Automated testing & building | GitHub Actions + Act (local) |
| **Monitoring** | Metrics & alerting | Prometheus + Grafana |
| **Logging** | Centralized logs | Loki + Promtail |
| **Container Registry** | Store Docker images | Local registry / GHCR |

---

## Prerequisites

### Minimum System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 8 GB | 16+ GB |
| **CPU** | 4 cores | 8+ cores |
| **Disk** | 20 GB free | 50+ GB free |
| **OS** | Linux (native) | Ubuntu 22.04 / Linux Mint 22 |

### Software Requirements

```bash
# Docker (required)
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in for group changes

# Basic tools
sudo apt-get install -y curl git make jq
```

---

## Quick Start

```bash
# Clone the repository (if not already done)
git clone https://github.com/7huannn/uitgo_monorepo.git
cd uitgo_monorepo

# Run the automated setup script
chmod +x scripts/setup-local-devops.sh
./scripts/setup-local-devops.sh full

# This will:
# 1. Install k3s (Kubernetes)
# 2. Install Helm
# 3. Setup local Docker registry
# 4. Install ArgoCD
# 5. Build and deploy UITGo
# 6. Deploy monitoring stack
```

---

## Detailed Setup Guide

### Step 1: Install k3s

```bash
# Install k3s (single-node Kubernetes)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verify installation
kubectl get nodes
# Expected output:
# NAME          STATUS   ROLES                  AGE   VERSION
# your-host     Ready    control-plane,master   1m    v1.28.x+k3s1
```

### Step 2: Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Step 3: Setup Local Container Registry

```bash
# Start local registry
docker run -d --name registry --restart=always -p 5000:5000 registry:2

# Configure k3s to use local registry
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<EOF
mirrors:
  "localhost:5000":
    endpoint:
      - "http://localhost:5000"
EOF

# Restart k3s
sudo systemctl restart k3s
```

### Step 4: Install ArgoCD

```bash
# Create namespace and install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Expose ArgoCD UI
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get ArgoCD URL
echo "ArgoCD URL: https://localhost:$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')"
```

### Step 5: Install Act (Local GitHub Actions)

```bash
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test by listing available jobs
cd /path/to/uitgo_monorepo
act -l
```

---

## CI/CD Pipeline

### Pipeline Stages

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Test   │───▶│  Lint   │───▶│  Build  │───▶│  Scan   │───▶│ Deploy  │
│         │    │         │    │ Images  │    │Security │    │(GitOps) │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `be_ci.yml` | PR / Push to backend/ | Test + lint Go code |
| `fe_ci.yml` | PR / Push to apps/ | Test + lint Flutter apps |
| `backend-cicd.yml` | Push to main/dev | Full CI/CD with image building |

### Running CI Locally with Act

```bash
cd /path/to/uitgo_monorepo

# List available workflows
act -l

# Run a specific workflow
act push -W .github/workflows/be_ci.yml

# Run with specific event
act pull_request

# Run with secrets
act -s GITHUB_TOKEN="$(cat ~/.github-token)"
```

### Manual Image Building

```bash
# Build all service images
docker build -t localhost:5000/uitgo/user-service:dev -f backend/user_service/Dockerfile .
docker build -t localhost:5000/uitgo/trip-service:dev -f backend/trip_service/Dockerfile .
docker build -t localhost:5000/uitgo/driver-service:dev -f backend/driver_service/Dockerfile .

# Push to local registry
docker push localhost:5000/uitgo/user-service:dev
docker push localhost:5000/uitgo/trip-service:dev
docker push localhost:5000/uitgo/driver-service:dev
```

---

## GitOps with ArgoCD

### How GitOps Works

1. **You change code** → commit → push to Git
2. **CI pipeline** runs tests, builds Docker images, updates image tags in `k8s/overlays/*/kustomization.yaml`
3. **ArgoCD watches** the Git repository
4. **ArgoCD detects changes** and automatically syncs to Kubernetes
5. **Your application updates** with zero manual intervention

### ArgoCD Applications

| Application | Branch | Overlay | Auto-Sync |
|-------------|--------|---------|-----------|
| `uitgo-dev` | dev | `k8s/overlays/dev` | ✅ Yes |
| `uitgo-staging` | main | `k8s/overlays/staging` | ❌ Manual |

### ArgoCD Commands

```bash
# Login to ArgoCD CLI
argocd login localhost:$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}') --insecure

# List applications
argocd app list

# Sync an application manually
argocd app sync uitgo-dev

# Get application status
argocd app get uitgo-dev

# View application logs
argocd app logs uitgo-dev
```

### Setting Up ArgoCD Application

```bash
# Apply the ArgoCD project and applications
kubectl apply -f k8s/argocd/project.yaml
kubectl apply -f k8s/argocd/uitgo-dev.yaml
```

---

## Kubernetes Deployment

### Directory Structure

```
k8s/
├── base/                    # Base manifests (shared)
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── databases.yaml       # PostgreSQL StatefulSets
│   ├── redis.yaml
│   ├── user-service.yaml
│   ├── trip-service.yaml
│   ├── driver-service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/                 # Development overrides
│   │   └── kustomization.yaml
│   └── staging/             # Staging overrides
│       └── kustomization.yaml
├── monitoring/              # Observability stack
│   ├── prometheus.yaml
│   ├── grafana.yaml
│   ├── loki.yaml
│   └── promtail.yaml
└── argocd/                  # ArgoCD applications
    ├── project.yaml
    ├── uitgo-dev.yaml
    └── uitgo-staging.yaml
```

### Manual Deployment (without ArgoCD)

```bash
# Deploy using Kustomize
kubectl apply -k k8s/overlays/dev

# Check deployment status
kubectl get pods -n uitgo
kubectl get svc -n uitgo

# View logs
kubectl logs -n uitgo deployment/user-service
kubectl logs -n uitgo deployment/trip-service
kubectl logs -n uitgo deployment/driver-service
```

### Scaling Services

```bash
# Scale a deployment
kubectl scale deployment/user-service -n uitgo --replicas=3

# Or edit the overlay
# k8s/overlays/dev/kustomization.yaml:
# replicas:
#   - name: user-service
#     count: 3
```

---

## Monitoring & Observability

### Accessing Dashboards

```bash
# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000
# Open: http://localhost:3000 (admin/uitgo)

# Prometheus
kubectl port-forward svc/prometheus -n monitoring 9090:9090
# Open: http://localhost:9090

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Open: https://localhost:8443
```

### Key Metrics to Monitor

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `http_request_duration_seconds` | Request latency | p95 > 500ms |
| `http_requests_total` | Request count | Error rate > 1% |
| `go_goroutines` | Active goroutines | > 1000 |
| `process_resident_memory_bytes` | Memory usage | > 80% limit |

### Viewing Logs in Grafana

1. Open Grafana → Explore
2. Select "Loki" as data source
3. Query: `{namespace="uitgo", app="user-service"}`
4. Filter by time range

### Example LogQL Queries

```logql
# All logs from uitgo namespace
{namespace="uitgo"}

# Error logs only
{namespace="uitgo"} |= "error"

# Specific service with JSON parsing
{namespace="uitgo", app="trip-service"} | json | level="error"

# Request logs with latency
{namespace="uitgo"} | json | latency_ms > 100
```

---

## Common Operations

### Deploying a New Version

```bash
# 1. Make code changes
git add .
git commit -m "feat: add new feature"

# 2. Push to trigger CI
git push origin dev

# 3. CI will:
#    - Run tests
#    - Build new images
#    - Update k8s/overlays/dev/kustomization.yaml
#    - Push changes

# 4. ArgoCD will automatically sync (if auto-sync enabled)
#    Or sync manually:
argocd app sync uitgo-dev
```

### Rolling Back

```bash
# Using ArgoCD
argocd app history uitgo-dev
argocd app rollback uitgo-dev <revision>

# Using kubectl
kubectl rollout undo deployment/user-service -n uitgo
kubectl rollout status deployment/user-service -n uitgo
```

### Checking Health

```bash
# All pods status
kubectl get pods -n uitgo

# Detailed pod info
kubectl describe pod <pod-name> -n uitgo

# Check events
kubectl get events -n uitgo --sort-by='.lastTimestamp'

# Service endpoints
kubectl get endpoints -n uitgo
```

### Accessing Services Locally

```bash
# Add to /etc/hosts
echo "127.0.0.1 uitgo.local grafana.uitgo.local" | sudo tee -a /etc/hosts

# Or use port-forwarding
kubectl port-forward svc/user-service -n uitgo 8081:8081
kubectl port-forward svc/trip-service -n uitgo 8082:8082
kubectl port-forward svc/driver-service -n uitgo 8083:8083
```

---

## Troubleshooting

### Common Issues

#### Pod stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n uitgo

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Image pull errors
```

#### Image Pull Errors

```bash
# Check if using local registry
kubectl get pod <pod-name> -n uitgo -o jsonpath='{.spec.containers[0].image}'

# Verify image exists
docker images | grep uitgo

# Check registry
curl http://localhost:5000/v2/_catalog
```

#### ArgoCD Sync Failed

```bash
# Get sync status
argocd app get uitgo-dev

# Check for diff
argocd app diff uitgo-dev

# Force sync
argocd app sync uitgo-dev --force
```

#### Database Connection Issues

```bash
# Check database pods
kubectl get pods -n uitgo | grep db

# Check logs
kubectl logs -n uitgo user-db-0

# Test connection from service pod
kubectl exec -it deployment/user-service -n uitgo -- sh
# Inside pod:
# nc -zv user-db 5432
```

### Useful Debug Commands

```bash
# Get all resources in namespace
kubectl get all -n uitgo

# Watch pods
kubectl get pods -n uitgo -w

# Shell into a pod
kubectl exec -it deployment/user-service -n uitgo -- sh

# Copy files from pod
kubectl cp uitgo/user-service-xxx:/app/logs ./logs

# View resource usage
kubectl top pods -n uitgo
kubectl top nodes
```

---

## Next Steps

1. **Week 1-2**: Set up k3s + local registry + basic deployments
2. **Week 3-4**: Configure ArgoCD + GitOps workflow
3. **Week 5-6**: Add monitoring (Prometheus + Grafana + Loki)
4. **Week 7-8**: Enhance CI/CD with security scanning
5. **Week 9-10**: Practice incident response + scaling
6. **Week 11-12**: Document everything + prepare for interviews

---

## Resources

- [k3s Documentation](https://docs.k3s.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kustomize Documentation](https://kustomize.io/)
