# UITGo - Diagram Specifications for README

Tài liệu này chứa mô tả chi tiết và mã LaTeX/TikZ để tạo các diagram chuyên nghiệp cho README.

---

## 📊 DIAGRAM 1: System Architecture Overview

### Mô tả
Diagram tổng quan kiến trúc hệ thống UITGo, thể hiện:
- 3 Flutter apps (Rider, Driver, Admin) ở phía client
- API Gateway (Nginx) làm entry point
- 3 Go microservices (User, Trip, Driver) 
- Database layer với 3 PostgreSQL và 1 Redis
- Monitoring stack (Prometheus, Grafana, Loki)

### Kích thước đề xuất: 1200x800 pixels

### LaTeX/TikZ Code

```latex
\documentclass[border=10pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning, fit, backgrounds}

\definecolor{flutter}{HTML}{02569B}
\definecolor{gateway}{HTML}{F7DF1E}
\definecolor{golang}{HTML}{00ADD8}
\definecolor{postgres}{HTML}{336791}
\definecolor{redis}{HTML}{DC382D}
\definecolor{monitoring}{HTML}{E6522C}

\begin{document}
\begin{tikzpicture}[
    node distance=1.5cm,
    box/.style={rectangle, rounded corners, draw, minimum width=2.5cm, minimum height=1cm, align=center, font=\small\sffamily},
    arrow/.style={-{Stealth[length=3mm]}, thick},
    label/.style={font=\footnotesize\sffamily}
]

% Client Layer
\node[box, fill=flutter!20, draw=flutter] (rider) {Rider App\\(Flutter)};
\node[box, fill=flutter!20, draw=flutter, right=of rider] (driver) {Driver App\\(Flutter)};
\node[box, fill=flutter!20, draw=flutter, right=of driver] (admin) {Admin App\\(Flutter)};

% Gateway Layer
\node[box, fill=gateway!30, draw=orange, below=1.5cm of driver, minimum width=8cm] (gateway) {API Gateway (Nginx/Ingress)\\Port 8080};

% Service Layer
\node[box, fill=golang!20, draw=golang, below=1.5cm of gateway, xshift=-4cm] (user) {user-service\\Go | Port 8081};
\node[box, fill=golang!20, draw=golang, below=1.5cm of gateway] (trip) {trip-service\\Go | Port 8082};
\node[box, fill=golang!20, draw=golang, below=1.5cm of gateway, xshift=4cm] (driverS) {driver-service\\Go | Port 8083};

% Database Layer
\node[box, fill=postgres!20, draw=postgres, below=1.5cm of user] (userdb) {PostgreSQL\\user\_service};
\node[box, fill=postgres!20, draw=postgres, below=1.5cm of trip] (tripdb) {PostgreSQL\\trip\_service};
\node[box, fill=postgres!20, draw=postgres, below=1.5cm of driverS] (driverdb) {PostgreSQL\\driver\_service};

% Redis (center bottom)
\node[box, fill=redis!20, draw=redis, below=3.5cm of trip, minimum width=4cm] (redis) {Redis\\GEO Index + Queue};

% Monitoring (side)
\node[box, fill=monitoring!20, draw=monitoring, right=2cm of driverS, minimum width=3cm] (prom) {Prometheus\\:9090};
\node[box, fill=monitoring!20, draw=monitoring, below=0.8cm of prom, minimum width=3cm] (grafana) {Grafana\\:3000};
\node[box, fill=monitoring!20, draw=monitoring, below=0.8cm of grafana, minimum width=3cm] (loki) {Loki\\Logs};

% Arrows - Client to Gateway
\draw[arrow] (rider) -- (gateway);
\draw[arrow] (driver) -- (gateway);
\draw[arrow] (admin) -- (gateway);

% Arrows - Gateway to Services
\draw[arrow] (gateway) -- node[label, left] {/auth/*} (user);
\draw[arrow] (gateway) -- node[label, right] {/v1/trips/*} (trip);
\draw[arrow] (gateway) -- node[label, right] {/v1/drivers/*} (driverS);

% Arrows - Services to DB
\draw[arrow] (user) -- (userdb);
\draw[arrow] (trip) -- (tripdb);
\draw[arrow] (driverS) -- (driverdb);

% Arrows - Services to Redis
\draw[arrow, dashed] (trip) -- (redis);
\draw[arrow, dashed] (driverS) -- (redis);

% Arrows - Services to Monitoring
\draw[arrow, dotted, gray] (user) -- (prom);
\draw[arrow, dotted, gray] (trip) -- (prom);
\draw[arrow, dotted, gray] (driverS) -- (prom);

% Labels
\node[above=0.5cm of driver, font=\large\bfseries\sffamily] {CLIENT LAYER};
\node[right=0.3cm of gateway, font=\small\sffamily, gray] {GATEWAY};
\node[right=0.3cm of trip, font=\small\sffamily, gray, yshift=0.5cm] {SERVICES};
\node[right=0.3cm of tripdb, font=\small\sffamily, gray, yshift=-0.5cm] {DATA};

\end{tikzpicture}
\end{document}
```

### Mô tả vẽ bằng tay hoặc Figma/Draw.io

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                   │
│                                                                             │
│    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                │
│    │  Rider App   │    │  Driver App  │    │  Admin App   │                │
│    │   Flutter    │    │   Flutter    │    │   Flutter    │                │
│    │   (iOS/      │    │   (iOS/      │    │   (Web)      │                │
│    │   Android/   │    │   Android)   │    │              │                │
│    │   Web)       │    │              │    │              │                │
│    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                │
│           │                   │                   │                         │
│           └───────────────────┼───────────────────┘                         │
│                               ▼                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                              GATEWAY                                        │
│    ┌────────────────────────────────────────────────────────────────────┐  │
│    │                    API Gateway (Nginx / Ingress)                    │  │
│    │                          Port: 8080                                 │  │
│    │         /auth/*  ──────  /v1/trips/*  ──────  /v1/drivers/*        │  │
│    └────────────┬─────────────────┬─────────────────────┬───────────────┘  │
│                 │                 │                     │                   │
├─────────────────┼─────────────────┼─────────────────────┼───────────────────┤
│                 ▼                 ▼                     ▼    SERVICES       │
│    ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│    │   user-service   │  │   trip-service   │  │  driver-service  │        │
│    │     Go 1.22+     │  │     Go 1.22+     │  │     Go 1.22+     │        │
│    │    Port: 8081    │  │    Port: 8082    │  │    Port: 8083    │        │
│    │                  │  │                  │  │                  │        │
│    │ • Authentication │  │ • Trip lifecycle │  │ • Driver onboard │        │
│    │ • User profiles  │  │ • Pricing        │  │ • Location track │        │
│    │ • Wallet/Topup   │  │ • WebSocket      │  │ • GEO matching   │        │
│    │ • Notifications  │  │                  │  │                  │        │
│    └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘        │
│             │                     │                     │                   │
├─────────────┼─────────────────────┼─────────────────────┼───────────────────┤
│             ▼                     ▼                     ▼    DATA LAYER    │
│    ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│    │    PostgreSQL    │  │    PostgreSQL    │  │    PostgreSQL    │        │
│    │   user_service   │  │   trip_service   │  │  driver_service  │        │
│    └──────────────────┘  └──────────────────┘  └──────────────────┘        │
│                                                                             │
│                        ┌──────────────────────┐                             │
│                        │        Redis         │                             │
│                        │  • GEO Index (GEOADD)│                             │
│                        │  • Match Queue       │                             │
│                        │  • Cache (Home Feed) │                             │
│                        └──────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 DIAGRAM 2: CI/CD Pipeline

### Mô tả
4-stage CI/CD pipeline với GitHub Actions:
1. **TEST**: Go test, vet, lint, coverage ≥80%
2. **BUILD**: Docker build, push to GHCR
3. **SECURITY**: Trivy scan, SBOM generation
4. **GITOPS**: Kustomize edit, ArgoCD sync

### Kích thước đề xuất: 1000x300 pixels

### LaTeX/TikZ Code

```latex
\documentclass[border=10pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning}

\definecolor{test}{HTML}{28A745}
\definecolor{build}{HTML}{007BFF}
\definecolor{security}{HTML}{FFC107}
\definecolor{gitops}{HTML}{6F42C1}

\begin{document}
\begin{tikzpicture}[
    node distance=0.5cm,
    stage/.style={rectangle, rounded corners=5pt, draw, minimum width=3cm, minimum height=2.5cm, align=center, font=\small\sffamily},
    arrow/.style={-{Stealth[length=4mm, width=3mm]}, line width=2pt, draw=gray!60},
    number/.style={circle, fill=white, draw, font=\footnotesize\bfseries, minimum size=6mm},
    item/.style={font=\tiny\sffamily}
]

% Stage 1: Test
\node[stage, fill=test!15, draw=test!80] (test) {
    \textbf{STAGE 1}\\[3pt]
    \textbf{TEST}\\[5pt]
    \begin{tabular}{l}
    \item • go test\\
    \item • go vet\\
    \item • golangci-lint\\
    \item • coverage ≥80\%
    \end{tabular}
};

% Stage 2: Build
\node[stage, fill=build!15, draw=build!80, right=1.5cm of test] (build) {
    \textbf{STAGE 2}\\[3pt]
    \textbf{BUILD}\\[5pt]
    \begin{tabular}{l}
    \item • docker build\\
    \item • push GHCR\\
    \item • layer caching\\
    \item • multi-arch
    \end{tabular}
};

% Stage 3: Security
\node[stage, fill=security!15, draw=security!80, right=1.5cm of build] (security) {
    \textbf{STAGE 3}\\[3pt]
    \textbf{SECURITY}\\[5pt]
    \begin{tabular}{l}
    \item • Trivy scan\\
    \item • SBOM gen\\
    \item • CVE check\\
    \item • SARIF upload
    \end{tabular}
};

% Stage 4: GitOps
\node[stage, fill=gitops!15, draw=gitops!80, right=1.5cm of security] (gitops) {
    \textbf{STAGE 4}\\[3pt]
    \textbf{GITOPS}\\[5pt]
    \begin{tabular}{l}
    \item • kustomize edit\\
    \item • git commit\\
    \item • ArgoCD sync\\
    \item • health check
    \end{tabular}
};

% Arrows
\draw[arrow] (test) -- (build);
\draw[arrow] (build) -- (security);
\draw[arrow] (security) -- (gitops);

% Title
\node[above=0.8cm of build, xshift=1cm, font=\large\bfseries\sffamily] {GitHub Actions CI/CD Pipeline};

\end{tikzpicture}
\end{document}
```

### Mô tả dạng bảng để vẽ

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        GITHUB ACTIONS CI/CD PIPELINE                           ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                 ║
║  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
║  │   🧪 STAGE 1    │     │   📦 STAGE 2    │     │   🔒 STAGE 3    │     │   🚀 STAGE 4    │
║  │      TEST       │────▶│      BUILD      │────▶│    SECURITY     │────▶│     GITOPS      │
║  │                 │     │                 │     │                 │     │                 │
║  │ • go test       │     │ • docker build  │     │ • Trivy scan    │     │ • kustomize     │
║  │ • go vet        │     │ • push GHCR     │     │ • SBOM generate │     │   edit image    │
║  │ • golangci-lint │     │ • layer cache   │     │ • CVE HIGH/CRIT │     │ • git commit    │
║  │ • coverage≥80%  │     │ • provenance    │     │ • SARIF upload  │     │   [skip ci]     │
║  │                 │     │                 │     │                 │     │ • ArgoCD sync   │
║  └─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
║         ▲                                                                       │
║         │                                                                       │
║         │                     Trigger: push to main/dev                         │
║         └───────────────────────────────────────────────────────────────────────┘
║                                    (auto-feedback)
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 📊 DIAGRAM 3: GitOps Workflow

### Mô tả
Luồng GitOps với ArgoCD:
1. Developer push code → GitHub
2. CI pipeline chạy test/build
3. CI cập nhật image tag trong kustomization.yaml
4. ArgoCD watch repo, phát hiện thay đổi
5. ArgoCD sync vào Kubernetes cluster
6. Health check xác nhận deployment thành công

### Kích thước đề xuất: 900x600 pixels

### LaTeX/TikZ Code

```latex
\documentclass[border=10pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning, fit}

\definecolor{dev}{HTML}{4A90D9}
\definecolor{github}{HTML}{24292E}
\definecolor{argocd}{HTML}{EF7B4D}
\definecolor{k8s}{HTML}{326CE5}

\begin{document}
\begin{tikzpicture}[
    node distance=1.2cm,
    box/.style={rectangle, rounded corners, draw, minimum width=3cm, minimum height=1.5cm, align=center, font=\small\sffamily},
    arrow/.style={-{Stealth[length=3mm]}, thick},
    dasharrow/.style={-{Stealth[length=3mm]}, thick, dashed}
]

% Developer
\node[box, fill=dev!20, draw=dev] (dev) {Developer\\Local};

% GitHub
\node[box, fill=github!10, draw=github, right=2cm of dev] (github) {GitHub\\Repository};

% CI
\node[box, fill=yellow!20, draw=orange, below=of github] (ci) {GitHub Actions\\CI Pipeline};

% GHCR
\node[box, fill=purple!10, draw=purple, right=2cm of ci] (ghcr) {GHCR\\Container Registry};

% ArgoCD
\node[box, fill=argocd!20, draw=argocd, below=of ci] (argocd) {ArgoCD\\GitOps Controller};

% K8s
\node[box, fill=k8s!20, draw=k8s, right=2cm of argocd, minimum width=4cm] (k8s) {Kubernetes Cluster\\(k3s/EKS)};

% Arrows
\draw[arrow] (dev) -- node[above, font=\tiny] {git push} (github);
\draw[arrow] (github) -- node[left, font=\tiny] {trigger} (ci);
\draw[arrow] (ci) -- node[above, font=\tiny] {docker push} (ghcr);
\draw[arrow] (ci) -- node[left, font=\tiny] {update k8s/} (github.south);
\draw[dasharrow] (github) -- node[left, font=\tiny] {watch} (argocd);
\draw[arrow] (argocd) -- node[above, font=\tiny] {sync} (k8s);
\draw[arrow] (ghcr) -- node[right, font=\tiny] {pull image} (k8s);

% Health feedback
\draw[dasharrow, gray] (k8s.south) to[out=-120,in=-60] node[below, font=\tiny] {health status} (argocd.south);

% Labels
\node[above=0.3cm of github, font=\large\bfseries\sffamily] {GitOps Workflow};

\end{tikzpicture}
\end{document}
```

### Mô tả dạng sequence

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Developer   │     │    GitHub    │     │   ArgoCD     │     │  Kubernetes  │
│              │     │  Repository  │     │   GitOps     │     │   Cluster    │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │                    │
       │  1. git push       │                    │                    │
       │───────────────────▶│                    │                    │
       │                    │                    │                    │
       │                    │  2. CI triggered   │                    │
       │                    │────────┐           │                    │
       │                    │        │ test      │                    │
       │                    │        │ build     │                    │
       │                    │        │ scan      │                    │
       │                    │◀───────┘           │                    │
       │                    │                    │                    │
       │                    │  3. Push image to GHCR                  │
       │                    │────────────────────────────────────────▶│
       │                    │                    │                    │
       │                    │  4. Update         │                    │
       │                    │  kustomization.yaml│                    │
       │                    │────────┐           │                    │
       │                    │◀───────┘           │                    │
       │                    │                    │                    │
       │                    │  5. Watch detects  │                    │
       │                    │     changes        │                    │
       │                    │◀ ─ ─ ─ ─ ─ ─ ─ ─ ─ │                    │
       │                    │                    │                    │
       │                    │                    │  6. Sync manifests │
       │                    │                    │───────────────────▶│
       │                    │                    │                    │
       │                    │                    │  7. Pull new image │
       │                    │                    │◀───────────────────│
       │                    │                    │                    │
       │                    │                    │  8. Health check   │
       │                    │                    │◀──────────────────▶│
       │                    │                    │                    │
       │                    │  9. Synced ✓       │                    │
       │◀ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │                    │
       │                    │                    │                    │
```

---

## 📊 DIAGRAM 4: Kubernetes Architecture

### Mô tả
Chi tiết cấu trúc Kubernetes:
- 3 Namespaces: argocd, uitgo, monitoring
- ArgoCD components trong argocd namespace
- Application workloads trong uitgo namespace
- Observability stack trong monitoring namespace

### Kích thước đề xuất: 1200x900 pixels

### LaTeX/TikZ Code

```latex
\documentclass[border=10pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning, fit, backgrounds}

\definecolor{k8s}{HTML}{326CE5}
\definecolor{argocd}{HTML}{EF7B4D}
\definecolor{app}{HTML}{00ADD8}
\definecolor{db}{HTML}{336791}
\definecolor{redis}{HTML}{DC382D}
\definecolor{prom}{HTML}{E6522C}

\begin{document}
\begin{tikzpicture}[
    node distance=0.8cm,
    box/.style={rectangle, rounded corners=3pt, draw, minimum width=2.2cm, minimum height=0.9cm, align=center, font=\tiny\sffamily},
    ns/.style={rectangle, rounded corners=5pt, draw, thick, minimum width=10cm, minimum height=4cm},
    arrow/.style={-{Stealth[length=2mm]}, thick}
]

% Cluster boundary
\node[rectangle, rounded corners=10pt, draw=k8s, thick, fill=k8s!5, minimum width=14cm, minimum height=12cm] (cluster) {};
\node[above=0.1cm of cluster.south, font=\small\bfseries\sffamily, k8s] {Kubernetes Cluster (k3s v1.33)};

% ArgoCD Namespace
\begin{scope}[shift={(0,4)}]
\node[ns, draw=argocd, fill=argocd!5] (argocd-ns) {};
\node[above=-0.1cm of argocd-ns.north, font=\footnotesize\bfseries\sffamily, argocd] {argocd namespace};

\node[box, fill=argocd!20] at (-3,0) (argo-server) {ArgoCD\\Server};
\node[box, fill=argocd!20] at (0,0) (argo-repo) {ArgoCD\\Repo Server};
\node[box, fill=argocd!20] at (3,0) (argo-ctrl) {ArgoCD\\Controller};
\end{scope}

% UITGo Namespace
\begin{scope}[shift={(0,-0.5)}]
\node[ns, draw=app, fill=app!5, minimum height=5cm] (uitgo-ns) {};
\node[above=-0.1cm of uitgo-ns.north, font=\footnotesize\bfseries\sffamily, app] {uitgo namespace};

% Ingress
\node[box, fill=yellow!20, draw=orange, minimum width=8cm] at (0,1.5) (ingress) {Ingress Controller (Traefik)};

% Services
\node[box, fill=app!20] at (-3.5,0.3) (user-svc) {user-service\\Deployment};
\node[box, fill=app!20] at (0,0.3) (trip-svc) {trip-service\\Deployment};
\node[box, fill=app!20] at (3.5,0.3) (driver-svc) {driver-service\\Deployment};

% Databases
\node[box, fill=db!20, draw=db] at (-3.5,-1) (user-db) {user-db\\StatefulSet};
\node[box, fill=db!20, draw=db] at (0,-1) (trip-db) {trip-db\\StatefulSet};
\node[box, fill=db!20, draw=db] at (3.5,-1) (driver-db) {driver-db\\StatefulSet};

% Redis
\node[box, fill=redis!20, draw=redis, minimum width=3cm] at (0,-2.2) (redis) {Redis Deployment};
\end{scope}

% Monitoring Namespace
\begin{scope}[shift={(0,-5.5)}]
\node[ns, draw=prom, fill=prom!5, minimum height=2cm, minimum width=12cm] (mon-ns) {};
\node[above=-0.1cm of mon-ns.north, font=\footnotesize\bfseries\sffamily, prom] {monitoring namespace};

\node[box, fill=prom!20] at (-4,0) (prometheus) {Prometheus};
\node[box, fill=prom!20] at (-1.3,0) (grafana) {Grafana};
\node[box, fill=prom!20] at (1.3,0) (loki) {Loki};
\node[box, fill=prom!20] at (4,0) (promtail) {Promtail\\DaemonSet};
\end{scope}

% Arrows
\draw[arrow] (ingress) -- (user-svc);
\draw[arrow] (ingress) -- (trip-svc);
\draw[arrow] (ingress) -- (driver-svc);

\draw[arrow] (user-svc) -- (user-db);
\draw[arrow] (trip-svc) -- (trip-db);
\draw[arrow] (driver-svc) -- (driver-db);

\draw[arrow, dashed] (trip-svc) -- (redis);
\draw[arrow, dashed] (driver-svc) -- (redis);

\end{tikzpicture}
\end{document}
```

### Mô tả chi tiết để vẽ

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER (k3s v1.33.6+k3s1)                   │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        argocd namespace                               │  │
│  │                                                                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │   ArgoCD    │  │   ArgoCD    │  │   ArgoCD    │  │   ArgoCD    │  │  │
│  │  │   Server    │  │ Repo Server │  │ Controller  │  │   Redis     │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│  │                                                                        │  │
│  │            ◀──── Watches Git repo ────▶ Auto-sync to uitgo            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         uitgo namespace                               │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │              Ingress Controller (Traefik)                        │  │  │
│  │  │         /auth/* ───── /v1/trips/* ───── /v1/drivers/*           │  │  │
│  │  └──────────────┬────────────────┬────────────────┬────────────────┘  │  │
│  │                 │                │                │                    │  │
│  │                 ▼                ▼                ▼                    │  │
│  │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐       │  │
│  │  │  user-service    │ │  trip-service    │ │ driver-service   │       │  │
│  │  │   Deployment     │ │   Deployment     │ │   Deployment     │       │  │
│  │  │  replicas: 1-2   │ │  replicas: 1-2   │ │  replicas: 1-2   │       │  │
│  │  │  Go 1.22+ / Gin  │ │  Go 1.22+ / Gin  │ │  Go 1.22+ / Gin  │       │  │
│  │  └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘       │  │
│  │           │                    │                    │                  │  │
│  │           ▼                    ▼                    ▼                  │  │
│  │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐       │  │
│  │  │    user-db       │ │    trip-db       │ │   driver-db      │       │  │
│  │  │   StatefulSet    │ │   StatefulSet    │ │   StatefulSet    │       │  │
│  │  │  PostgreSQL 15   │ │  PostgreSQL 15   │ │  PostgreSQL 15   │       │  │
│  │  │  PVC: 1Gi        │ │  PVC: 1Gi        │ │  PVC: 1Gi        │       │  │
│  │  └──────────────────┘ └──────────────────┘ └──────────────────┘       │  │
│  │                                                                        │  │
│  │                    ┌──────────────────────┐                            │  │
│  │                    │        Redis         │                            │  │
│  │                    │     Deployment       │                            │  │
│  │                    │  • GEO Index         │                            │  │
│  │                    │  • Match Queue       │                            │  │
│  │                    │  • Cache Layer       │                            │  │
│  │                    └──────────────────────┘                            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      monitoring namespace                             │  │
│  │                                                                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │ Prometheus  │  │   Grafana   │  │    Loki     │  │  Promtail   │  │  │
│  │  │ Deployment  │  │ Deployment  │  │ Deployment  │  │  DaemonSet  │  │  │
│  │  │   :9090     │  │   :3000     │  │   :3100     │  │             │  │  │
│  │  │             │  │             │  │             │  │             │  │  │
│  │  │  Scrape     │  │  4 Custom   │  │  Log        │  │  Ship logs  │  │  │
│  │  │  /metrics   │  │  Dashboards │  │  Storage    │  │  from pods  │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 DIAGRAM 5: Trip Matching Flow

### Mô tả
Luồng ghép chuyến từ rider request đến driver assignment:
1. Rider tạo trip request
2. trip-service ghi vào Postgres và đẩy vào Redis queue
3. Match worker consume từ queue
4. Driver-service tìm driver gần nhất bằng Redis GEO
5. Cập nhật trạng thái và notify qua WebSocket

### Kích thước đề xuất: 1000x600 pixels

### Mô tả chi tiết

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          TRIP MATCHING FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

                   ┌────────────────┐
                   │   Rider App    │
                   │   (Flutter)    │
                   └───────┬────────┘
                           │ 1. POST /v1/trips
                           │    {pickup, dropoff, vehicleType}
                           ▼
              ┌────────────────────────┐
              │     trip-service       │
              │      (Go 1.22+)        │
              └────────────┬───────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               │
    ┌─────────────┐  ┌─────────────┐       │
    │  PostgreSQL │  │    Redis    │       │
    │  trip_db    │  │   Queue     │       │
    │             │  │ LPUSH       │       │
    │ • Save trip │  │ trip:       │       │
    │ • status:   │  │ requests    │       │
    │   pending   │  │             │       │
    └─────────────┘  └──────┬──────┘       │
                            │              │
                            │ 2. BRPOP     │
                            ▼              │
                   ┌────────────────┐      │
                   │  Match Worker  │      │
                   │  (Background)  │      │
                   └───────┬────────┘      │
                           │               │
                           │ 3. Find nearest driver
                           ▼               │
              ┌────────────────────────┐   │
              │    driver-service      │   │
              │      (Go 1.22+)        │   │
              └────────────┬───────────┘   │
                           │               │
           ┌───────────────┴───────────┐   │
           ▼                           ▼   │
    ┌─────────────┐             ┌─────────────┐
    │  PostgreSQL │             │    Redis    │
    │  driver_db  │             │    GEO      │
    │             │             │             │
    │ • Driver    │             │ GEORADIUS   │
    │   profile   │◀───────────▶│ drivers:    │
    │ • status    │             │ available   │
    └─────────────┘             └─────────────┘
           │                           │
           │ 4. Select & Lock driver   │
           ▼                           │
    ┌─────────────────────────────────┐│
    │    Update trip status           ││
    │    driver_id = selected         ││
    │    status = driver_assigned     ││
    └─────────────────────────────────┘│
                           │           │
                           │ 5. WebSocket notify
                           ▼
    ┌─────────────────────────────────────────────┐
    │                                             │
    │  ┌─────────────┐         ┌─────────────┐   │
    │  │ Rider App   │         │ Driver App  │   │
    │  │             │         │             │   │
    │  │  "Driver    │         │  "New trip  │   │
    │  │   found!"   │         │   request!" │   │
    │  └─────────────┘         └─────────────┘   │
    │                                             │
    └─────────────────────────────────────────────┘
```

---

## 📊 DIAGRAM 6: Monitoring Stack

### Mô tả
Luồng metrics và logs trong observability stack:
- Prometheus scrape /metrics từ services mỗi 15s
- Promtail (DaemonSet) collect logs từ tất cả pods
- Loki store logs với label indexing
- Grafana query cả Prometheus và Loki

### Kích thước đề xuất: 900x500 pixels

### Mô tả chi tiết

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OBSERVABILITY STACK                                   │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────────┐
    │                         uitgo namespace                          │
    │                                                                   │
    │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐             │
    │  │user-service │   │trip-service │   │driver-service│             │
    │  │  /metrics   │   │  /metrics   │   │   /metrics  │             │
    │  │  /health    │   │  /health    │   │   /health   │             │
    │  │             │   │             │   │             │             │
    │  │  stdout     │   │  stdout     │   │  stdout     │             │
    │  │  (JSON)     │   │  (JSON)     │   │  (JSON)     │             │
    │  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘             │
    │         │                 │                 │                     │
    └─────────┼─────────────────┼─────────────────┼─────────────────────┘
              │                 │                 │
              │    METRICS      │                 │         LOGS
              │    (pull)       │                 │         (push)
              │                 │                 │
    ┌─────────▼─────────────────▼─────────────────▼─────────────────────┐
    │                      monitoring namespace                         │
    │                                                                   │
    │  ┌───────────────────────────────────────────────────────────┐   │
    │  │                     Prometheus                             │   │
    │  │                                                            │   │
    │  │  • Scrape interval: 15s                                   │   │
    │  │  • Targets: user-service, trip-service, driver-service    │   │
    │  │  • Metrics: go_*, http_request_*, process_*               │   │
    │  │  • Alert rules: alert-rules.yaml                          │   │
    │  │                                                            │   │
    │  └────────────────────────────┬──────────────────────────────┘   │
    │                               │                                   │
    │  ┌────────────────────────────▼──────────────────────────────┐   │
    │  │                       Grafana                              │   │
    │  │                                                            │   │
    │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │
    │  │  │  Dashboard  │  │  Dashboard  │  │  Dashboard  │        │   │
    │  │  │  Services   │  │   Alerts    │  │    SLO      │        │   │
    │  │  └─────────────┘  └─────────────┘  └─────────────┘        │   │
    │  │                                                            │   │
    │  │  Datasources:                                              │   │
    │  │  • Prometheus (PBFA97CFB590B2093)                         │   │
    │  │  • Loki                                                    │   │
    │  │                                                            │   │
    │  └───────────────────────────────────────────────────────────┘   │
    │                               ▲                                   │
    │                               │                                   │
    │  ┌────────────────────────────┴──────────────────────────────┐   │
    │  │                        Loki                                │   │
    │  │                                                            │   │
    │  │  • Label indexing: namespace, pod, container              │   │
    │  │  • Retention: configurable                                │   │
    │  │  • LogQL queries                                          │   │
    │  │                                                            │   │
    │  └────────────────────────────▲──────────────────────────────┘   │
    │                               │                                   │
    │  ┌────────────────────────────┴──────────────────────────────┐   │
    │  │                     Promtail (DaemonSet)                   │   │
    │  │                                                            │   │
    │  │  • Runs on every node                                     │   │
    │  │  • Tails /var/log/containers/*.log                        │   │
    │  │  • Adds Kubernetes labels                                 │   │
    │  │  • Ships to Loki:3100                                     │   │
    │  │                                                            │   │
    │  └───────────────────────────────────────────────────────────┘   │
    │                                                                   │
    └───────────────────────────────────────────────────────────────────┘

                           ACCESS ENDPOINTS

    ┌─────────────────┬─────────────────┬─────────────────┐
    │   Prometheus    │     Grafana     │      Loki       │
    │   :9090         │     :3000       │     :3100       │
    │                 │  admin/uitgo    │                 │
    └─────────────────┴─────────────────┴─────────────────┘
```

---

## 📊 DIAGRAM 7: Tech Stack Overview

### Mô tả
Tổng hợp toàn bộ công nghệ sử dụng trong dự án, phân theo layer

### Kích thước đề xuất: 1000x600 pixels

### Mô tả chi tiết

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             TECH STACK                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  📱 FRONTEND                                                         │   │
│  │                                                                       │   │
│  │  Flutter 3.x     Dart 3.x     Material 3     GetX/Bloc              │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  iOS • Android • Web                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ⚙️ BACKEND                                                          │   │
│  │                                                                       │   │
│  │  Go 1.22+    Gin Framework    GORM    JWT    WebSocket              │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  Microservices Architecture (user, trip, driver)                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  💾 DATA                                                             │   │
│  │                                                                       │   │
│  │  PostgreSQL 15    Redis 7 (GEO)    PVC Storage                      │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  3 Databases + 1 Cache/Queue                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ☸️ INFRASTRUCTURE                                                   │   │
│  │                                                                       │   │
│  │  k3s/Kubernetes    Docker    Kustomize    Terraform                 │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  Traefik Ingress • Nginx Gateway • StatefulSets                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  🔄 CI/CD                                                            │   │
│  │                                                                       │   │
│  │  GitHub Actions    ArgoCD    GHCR    Trivy    Kustomize             │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  GitOps • Automated Testing • Security Scanning                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  📊 OBSERVABILITY                                                    │   │
│  │                                                                       │   │
│  │  Prometheus    Grafana    Loki    Promtail    Sentry                │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  Metrics • Dashboards • Centralized Logging • Error Tracking         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  🧪 TESTING                                                          │   │
│  │                                                                       │   │
│  │  Go Test    Flutter Test    k6 Load Testing    golangci-lint        │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │   │
│  │  Unit • Integration • Performance • Static Analysis                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🎨 Color Palette for Diagrams

Sử dụng bảng màu nhất quán cho tất cả diagrams:

| Component | Hex Color | RGB | Usage |
|-----------|-----------|-----|-------|
| Flutter/Dart | `#02569B` | 2, 86, 155 | Client apps |
| Go/Gin | `#00ADD8` | 0, 173, 216 | Backend services |
| PostgreSQL | `#336791` | 51, 103, 145 | Databases |
| Redis | `#DC382D` | 220, 56, 45 | Cache/Queue |
| Kubernetes | `#326CE5` | 50, 108, 229 | Cluster elements |
| ArgoCD | `#EF7B4D` | 239, 123, 77 | GitOps |
| Prometheus | `#E6522C` | 230, 82, 44 | Monitoring |
| Grafana | `#F46800` | 244, 104, 0 | Dashboards |
| GitHub | `#24292E` | 36, 41, 46 | CI/CD |
| Nginx | `#009639` | 0, 150, 57 | Gateway |

---

## 📝 Tools Recommendation for Creating Diagrams

### Option 1: Draw.io (diagrams.net) - FREE
- Export as SVG or PNG
- Has Kubernetes icons built-in
- https://app.diagrams.net/

### Option 2: Excalidraw - FREE
- Hand-drawn style, modern look
- Export as SVG
- https://excalidraw.com/

### Option 3: Figma - FREE tier
- Professional design tool
- Perfect for README images
- https://figma.com/

### Option 4: LaTeX + TikZ → PDF → PNG
```bash
# Compile LaTeX
pdflatex diagram.tex

# Convert to PNG
convert -density 300 diagram.pdf -quality 100 diagram.png
```

### Option 5: Lucidchart - FREE tier
- Cloud-based diagramming
- Many templates available

---

## 📂 Suggested Image Sizes for GitHub README

| Diagram | Recommended Size | Format |
|---------|------------------|--------|
| System Architecture | 1200x800 px | PNG/SVG |
| CI/CD Pipeline | 1000x300 px | PNG/SVG |
| GitOps Workflow | 900x600 px | PNG/SVG |
| K8s Architecture | 1200x900 px | PNG/SVG |
| Trip Matching Flow | 1000x600 px | PNG/SVG |
| Monitoring Stack | 900x500 px | PNG/SVG |
| Tech Stack | 1000x600 px | PNG/SVG |

---

## 📁 Suggested Directory Structure

```
docs/
└── images/
    ├── architecture-overview.png
    ├── cicd-pipeline.png
    ├── gitops-workflow.png
    ├── k8s-architecture.png
    ├── trip-matching-flow.png
    ├── monitoring-stack.png
    └── tech-stack.png
```

Sau khi tạo xong images, update README.md với:

```markdown
## System Architecture
![System Architecture](docs/images/architecture-overview.png)

## CI/CD Pipeline
![CI/CD Pipeline](docs/images/cicd-pipeline.png)
```
