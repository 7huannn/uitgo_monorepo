<p align="center">
  <img src="assets/image1.png" alt="UITGo Logo" width="120"/>
</p>

<h1 align="center">UITGo Monorepo</h1>

<p align="center">
  <strong>Cloud-Native Ride-Hailing Platform</strong><br>
  <em>Microservices • GitOps • Full Observability</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go" alt="Go">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Kubernetes-Ready-326CE5?style=flat&logo=kubernetes" alt="Kubernetes">
  <img src="https://img.shields.io/badge/Terraform-IaC-7B42BC?style=flat&logo=terraform" alt="Terraform">
  <img src="https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?style=flat&logo=argo" alt="ArgoCD">
</p>

<p align="center">
  <a href="https://sonarcloud.io/dashboard?id=7huannn_uitgo_monorepo"><img src="https://img.shields.io/badge/SonarCloud-Quality%20Gate-F3702A?style=flat&logo=sonarcloud" alt="SonarCloud"></a>
  <a href="https://app.aikido.dev"><img src="https://img.shields.io/badge/Aikido-Security%20Scan-6366F1?style=flat&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyTDIgN2wxMCA1IDEwLTUtMTAtNXptMCAybDcuNTMgMy43N0wxMiAxMS41MyA0LjQ3IDcuNzcgMTIgNHoiLz48L3N2Zz4=" alt="Aikido Security"></a>
</p>

---

## Overview

**UITGo** is a sample ride-hailing platform built with microservices architecture, where Flutter mobile apps communicate via API Gateway to Go services. The project includes:

- **CI/CD Pipeline** with GitHub Actions, Trivy security scanning, K6 load testing
- **GitOps** with ArgoCD auto-sync
- **Full Observability** with Prometheus, Grafana, Loki, Jaeger
- **Security Scanning** with SonarCloud + Aikido Security (GitHub integration)
- **Infrastructure as Code** with Terraform (AWS) and Kubernetes manifests

---

## System Architecture

<p align="center">
  <img src="architecture.png" alt="UITGo System Architecture" width="100%"/>
</p>

### Architecture Highlights

| Layer | Components | Description |
|-------|------------|-------------|
| **Client** | Flutter (iOS/Android/Web) | Rider & Driver mobile applications |
| **CI/CD** | GitHub Actions → GHCR → ArgoCD | Automated build, test, scan, deploy pipeline |
| **Gateway** | Traefik / Nginx Ingress | API routing, rate limiting, SSL termination |
| **Services** | user-service, trip-service, driver-service | Go microservices with dedicated databases |
| **Data** | PostgreSQL × 3, Redis (GEO + Queue) | Isolated databases per service |
| **Observability** | Prometheus, Grafana, Loki, Jaeger, Sentry | Metrics, logs, traces, error tracking |
| **Security** | SonarCloud, Aikido, Trivy | Code quality, SAST, dependency & container scanning |

---

## Service Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Flutter Mobile Apps                               │
│                    (Rider App • Driver App • Admin)                      │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ REST / WebSocket
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     API Gateway (Traefik/Nginx)                          │
│              /auth/* │ /v1/trips/* │ /v1/drivers/* │ /ws/*              │
└────────┬───────────────────┬───────────────────┬────────────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  user-service   │ │  trip-service   │ │ driver-service  │
│     :8081       │ │     :8082       │ │     :8083       │
│                 │ │                 │ │                 │
│ • Auth/JWT      │ │ • Trip CRUD     │ │ • Driver mgmt   │
│ • User profile  │ │ • WebSocket     │ │ • GEO search    │
│ • Wallet        │ │ • Fare calc     │ │ • Trip matching │
│ • Notifications │ │ • Trip history  │ │ • Queue worker  │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   PostgreSQL    │ │   PostgreSQL    │ │   PostgreSQL    │
│   user_db       │ │   trip_db       │ │   driver_db     │
└─────────────────┘ └─────────────────┘ └─────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
            ┌─────────────┐           ┌─────────────┐
            │    Redis    │           │    Redis    │
            │  GEO Index  │           │ Match Queue │
            └─────────────┘           └─────────────┘
```

### Service Endpoints

| Service | Port | Storage | Responsibilities |
|---------|------|---------|------------------|
| **api-gateway** | 8080 | — | Traffic routing, rate limiting |
| **user-service** | 8081 | PostgreSQL | Auth, profiles, wallet, notifications |
| **trip-service** | 8082 | PostgreSQL | Trip lifecycle, WebSocket, fare calculation |
| **driver-service** | 8083 | PostgreSQL | Driver onboarding, GEO search, trip matching |
| **redis** | 6379 | In-memory | GEO index + async match queue |

---

## Quick Start

### Prerequisites

- Docker + Docker Compose v2
- Make
- Go 1.22+ (optional, for local development)
- Flutter 3.x (optional, for mobile development)
- kubectl + k3s/kind (optional, for Kubernetes)

### Option 1: Docker Compose (Simplest)

```bash
# Start all services
docker compose up --build

# Access points
# API Gateway: http://localhost:8080
# Prometheus:  http://localhost:9090
# Grafana:     http://localhost:3000 (admin/uitgo)
```

### Option 2: Kubernetes with K3s (Production-like)

```bash
# Full automated setup
./scripts/setup-local-devops.sh full

# Or step by step
make k8s-build        # Build images
make k8s-deploy       # Deploy services
make k8s-monitoring   # Deploy observability stack
make k8s-status       # Check status

# Access via Ingress: http://uitgo.local
```

### Option 3: Backend Only (Development)

```bash
cd backend
make migrate          # Run migrations
make seed             # Seed demo data
make run              # Start server on :8080
```

---

## CI/CD Pipeline

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│     TEST     │──▶│    BUILD     │──▶│   SECURITY   │──▶│  LOAD TEST   │──▶│    GITOPS    │
│              │   │              │   │              │   │              │   │              │
│ • go test    │   │ • Docker     │   │ • Trivy      │   │ • K6 smoke   │   │ • Kustomize  │
│ • go vet     │   │   multi-     │   │ • SonarCloud │   │ • search     │   │   update     │
│ • golangci   │   │   stage      │   │ • Aikido     │   │ • home_meta  │   │ • ArgoCD     │
│ • coverage   │   │ • GHCR       │   │ • SBOM       │   │              │   │   auto-sync  │
│   (≥80%)     │   │   push       │   │              │   │              │   │              │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

### Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `backend-cicd.yml` | Push to dev/main | Full pipeline: test → build → scan → load test → GitOps |
| `be_ci.yml` | PR to backend/** | Go vet, tests, golangci-lint |
| `fe_ci.yml` | PR to apps/** | Flutter analyze, test, build web |
| `terraform.yml` | PR to infra/** | Terraform plan, validate |
| `seal-secrets.yml` | Manual | Seal secrets for GitOps |

---

## Security

### Security Scanning Tools

UITGo uses **multi-layer security scanning** via GitHub integration:

| Tool | Integration | Scope | Dashboard |
|------|-------------|-------|-----------|
| **SonarCloud** | GitHub App | Code quality, bugs, code smells, coverage | [sonarcloud.io](https://sonarcloud.io/dashboard?id=7huannn_uitgo_monorepo) |
| **Aikido Security** | GitHub App | SAST, dependencies, secrets, IaC, containers | [app.aikido.dev](https://app.aikido.dev) |
| **Trivy** | GitHub Actions | Container image vulnerabilities, SBOM | PR comments + SARIF |

### How Security Scanning Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Push / Pull Request                              │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SonarCloud    │    │     Aikido      │    │     Trivy       │
│   (GitHub App)  │    │  (GitHub App)   │    │ (GitHub Action) │
│                 │    │                 │    │                 │
│ • Code Quality  │    │ • SAST Analysis │    │ • Image Scan    │
│ • Test Coverage │    │ • Dependency    │    │ • CVE Detection │
│ • Code Smells   │    │   Vulnerabilities│   │ • SBOM Generate │
│ • Duplications  │    │ • Secret Leaks  │    │ • SARIF Report  │
│ • Security      │    │ • IaC Misconfig │    │                 │
│   Hotspots      │    │ • License Risk  │    │                 │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      PR Status Checks & Comments                         │
│         Pass / Block based on Quality Gate & Security Policy             │
└─────────────────────────────────────────────────────────────────────────┘
```

### SonarCloud Integration

- **Automatic Analysis**: Every PR is analyzed for code quality
- **Quality Gate**: Block merge if quality gate fails
- **Coverage Tracking**: Track test coverage over time
- **Dashboard**: https://sonarcloud.io/dashboard?id=7huannn_uitgo_monorepo

### Aikido Security Integration

- **Automatic Scan**: Every PR is scanned for security vulnerabilities
- **Multi-Scanner**: Dependencies, SAST, secrets, IaC, containers
- **PR Comments**: Findings are posted directly to PR
- **Block on Critical**: High/Critical issues block PR merge
- **Dashboard**: https://app.aikido.dev

### Authentication Security

- JWT access tokens (15 min TTL)
- Encrypted refresh tokens (30 days, rotate on use)
- Rate limiting: 10 req/min for auth endpoints

### Secrets Management

- **SealedSecrets**: GitOps-friendly encrypted secrets
- See `docs/END_TO_END_DEVOPS_SETUP.md` for setup guide

---

## Observability

### Metrics & Dashboards (Prometheus + Grafana)

- **Grafana**: http://localhost:3000 (admin/uitgo)
- Pre-configured dashboards:
  - `uitgo-overview` - System health
  - `uitgo-services` - Per-service metrics
  - `uitgo-slo` - SLO/SLI tracking

### Logging (Loki + Promtail)

- Centralized JSON logs from all services
- Query via Grafana Explore

### Tracing (Jaeger)

- Distributed tracing with OpenTelemetry
- Jaeger UI: http://localhost:16686

### Error Tracking (Sentry)

- Backend and Flutter error reporting
- Test: `curl -H "X-Internal-Token: $KEY" http://localhost:8080/internal/debug/panic`

---

## Testing

### Unit Tests

```bash
# Backend
cd backend && make test

# Flutter
cd apps/rider_app && flutter test
cd apps/driver_app && flutter test
```

### Load Tests (K6)

```bash
# Quick smoke test
make loadtest-local ACCESS_TOKEN=<jwt>

# Full suite
make loadtest-full-suite

# Available scenarios:
# - search_only.js     (driver GEO search)
# - home_meta.js       (home feed)
# - trip_matching.js   (full trip flow)
# - stress_test.js     (high load)
# - soak_test.js       (long duration)
```

---

## Project Structure

```
uitgo_monorepo/
├── apps/
│   ├── rider_app/        # Flutter rider application
│   ├── driver_app/       # Flutter driver application
│   └── admin_app/        # Admin dashboard prototype
├── backend/
│   ├── cmd/server/       # Monolith entrypoint
│   ├── user_service/     # User microservice
│   ├── trip_service/     # Trip microservice
│   ├── driver_service/   # Driver microservice
│   └── internal/         # Shared packages
├── k8s/                  # Kubernetes manifests
├── infra/                # Terraform + staging compose
├── loadtests/            # K6 load test scenarios
├── observability/        # Prometheus/Grafana configs
├── scripts/              # Automation scripts
├── docs/                 # Documentation
└── ADR/                  # Architecture Decision Records
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/DEVOPS_IMPLEMENTATION_SUMMARY.md`](docs/DEVOPS_IMPLEMENTATION_SUMMARY.md) | DevOps infrastructure overview |
| [`docs/END_TO_END_DEVOPS_SETUP.md`](docs/END_TO_END_DEVOPS_SETUP.md) | Complete CI/CD setup guide |
| [`docs/architecture-stage1.md`](docs/architecture-stage1.md) | Microservice skeleton & environment |
| [`docs/moduleA_scalability.md`](docs/moduleA_scalability.md) | Performance optimization & K6 results |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Detailed system architecture |
| [`backend/README.md`](backend/README.md) | Backend API documentation |

---

## Makefile Commands

<details>
<summary><strong>Development</strong></summary>

```bash
make dev              # Docker Compose up --build
make down             # Docker Compose down
make logs             # View logs
```
</details>

<details>
<summary><strong>Kubernetes</strong></summary>

```bash
make k8s-setup        # Full local K8s setup
make k8s-build        # Build & push images
make k8s-deploy       # Deploy to K8s (dev)
make k8s-deploy-staging  # Deploy staging overlay
make k8s-monitoring   # Deploy observability
make k8s-status       # Check cluster status
make k8s-clean        # Cleanup resources
```
</details>

<details>
<summary><strong>CI/CD</strong></summary>

```bash
make ci-local         # Run CI locally (Act)
make argocd-sync      # Sync ArgoCD apps
make validate-manifests  # Validate K8s YAML
```
</details>

<details>
<summary><strong>Load Testing</strong></summary>

```bash
make loadtest-local        # Local load test
make loadtest-full-suite   # Complete test suite
make loadtest-stress       # Stress test
```
</details>

---

## Contributing

We welcome contributions! Please see our development workflow:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

> **Note**: All PRs are automatically checked by SonarCloud (code quality) and Aikido Security (vulnerability scanning).

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [University of Information Technology (UIT)](https://www.uit.edu.vn/) - Academic support
- [Gin Web Framework](https://gin-gonic.com/) - Go HTTP framework
- [Flutter](https://flutter.dev/) - Cross-platform UI toolkit
- [ArgoCD](https://argoproj.github.io/cd/) - GitOps continuous delivery
- [Kubernetes](https://kubernetes.io/) - Container orchestration

---

<p align="center">
  <strong>Built with ❤️ by UITGo Team</strong><br>
  <sub>University of Information Technology, Vietnam National University - Ho Chi Minh City</sub>
</p>

<p align="center">
  <a href="https://github.com/7huannn/uitgo_monorepo/issues">Report Bug</a> •
  <a href="https://github.com/7huannn/uitgo_monorepo/issues">Request Feature</a> •
  <a href="https://github.com/7huannn/uitgo_monorepo/discussions">Discussions</a>
</p>
