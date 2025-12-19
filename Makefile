K6 ?= k6
API_BASE ?= http://localhost:8080
ACCESS_TOKEN ?=
LOADTEST_RESULTS_DIR := loadtests/results
TRIP_MATCHING_RESULT ?= $(LOADTEST_RESULTS_DIR)/trip_matching.json
LOCAL_API_BASE ?= http://localhost:8080
AWS_API_BASE ?= https://staging.api.uitgo.dev
RPS_STEPS ?= 20 40 60 80 120
PYTHON ?= python
REPORT_DIR := loadtests/report

.PHONY: loadtest-trip-matching
loadtest-trip-matching:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required (Bearer token for authenticated requests)"; \
		exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) $(K6) run --out json=$(TRIP_MATCHING_RESULT) loadtests/k6/trip_matching.js
	@echo "k6 results exported to $(TRIP_MATCHING_RESULT)"

.PHONY: loadtest-local
loadtest-local:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required (Bearer token for authenticated requests)"; \
		exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(LOCAL_API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) $(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/local_home_meta.json loadtests/k6/home_meta.js
	API_BASE=$(LOCAL_API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) $(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/local_search_only.json loadtests/k6/search_only.js
	@for r in $(RPS_STEPS); do \
		API_BASE=$(LOCAL_API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) TARGET_RPS=$$r $(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/local_run_$$r.json loadtests/k6/trip_matching.js; \
	done

.PHONY: loadtest-aws
loadtest-aws:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required (Bearer token for authenticated requests)"; \
		exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(AWS_API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) $(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/aws_home_meta.json loadtests/k6/home_meta.js
	API_BASE=$(AWS_API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) $(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/aws_search_only.json loadtests/k6/search_only.js
	@for r in $(RPS_STEPS); do \
		API_BASE=$(AWS_API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) TARGET_RPS=$$r $(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/aws_run_$$r.json loadtests/k6/trip_matching.js; \
	done

.PHONY: loadtest-summarize
loadtest-summarize:
	mkdir -p $(REPORT_DIR)
	$(PYTHON) loadtests/plots/summarize_results.py

.PHONY: loadtest-plot
loadtest-plot:
	$(PYTHON) loadtests/plots/aimd_latency.py

.PHONY: loadtest-compare
loadtest-compare:
	$(PYTHON) loadtests/plots/generate_comparison.py

.PHONY: loadtest-all
loadtest-all: loadtest-local loadtest-aws loadtest-summarize loadtest-plot loadtest-compare

.PHONY: loadtest-setup-aws
loadtest-setup-aws:
	@echo "Setting up AWS test users..."
	./loadtests/scripts/aws_setup_test_users.sh
	@echo ""
	@echo "To use the token, run: source .env.aws.loadtest"

# ============ Additional Load Tests for Module A ============

.PHONY: loadtest-soak
loadtest-soak:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required"; exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) \
		SOAK_DURATION=$(SOAK_DURATION) STEADY_VUS=$(STEADY_VUS) RPS=$(RPS) \
		$(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/soak_test.json loadtests/k6/soak_test.js
	@echo "Soak test results: $(LOADTEST_RESULTS_DIR)/soak_test.json"

.PHONY: loadtest-stress
loadtest-stress:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required"; exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) \
		MAX_RPS=$(MAX_RPS) STRESS_DURATION=$(STRESS_DURATION) \
		$(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/stress_test.json loadtests/k6/stress_test.js
	@echo "Stress test results: $(LOADTEST_RESULTS_DIR)/stress_test.json"

.PHONY: loadtest-spike
loadtest-spike:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required"; exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) \
		NORMAL_RPS=$(NORMAL_RPS) SPIKE_MULTIPLIER=$(SPIKE_MULTIPLIER) \
		$(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/spike_test.json loadtests/k6/spike_test.js
	@echo "Spike test results: $(LOADTEST_RESULTS_DIR)/spike_test.json"

.PHONY: loadtest-websocket
loadtest-websocket:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required"; exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) \
		WS_VUS=$(WS_VUS) WS_DURATION=$(WS_DURATION) \
		$(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/websocket_test.json loadtests/k6/websocket_test.js
	@echo "WebSocket test results: $(LOADTEST_RESULTS_DIR)/websocket_test.json"

.PHONY: loadtest-driver-location
loadtest-driver-location:
	@if [ -z "$(DRIVER_TOKEN)" ] && [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "DRIVER_TOKEN or ACCESS_TOKEN is required"; exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) DRIVER_TOKEN=$(DRIVER_TOKEN) ACCESS_TOKEN=$(ACCESS_TOKEN) \
		NUM_DRIVERS=$(NUM_DRIVERS) UPDATE_INTERVAL=$(UPDATE_INTERVAL) TEST_DURATION=$(TEST_DURATION) \
		$(K6) run --summary-export $(LOADTEST_RESULTS_DIR)/driver_location_test.json loadtests/k6/driver_location_test.js
	@echo "Driver location test results: $(LOADTEST_RESULTS_DIR)/driver_location_test.json"

.PHONY: loadtest-full-suite
loadtest-full-suite: loadtest-local loadtest-soak loadtest-stress loadtest-spike loadtest-summarize loadtest-plot loadtest-charts
	@echo "Full load test suite completed"

.PHONY: loadtest-charts
loadtest-charts:
	$(PYTHON) loadtests/plots/generate_report_charts.py
	@echo "Charts generated in loadtests/plots/"

# ============ Kubernetes / DevOps Commands ============

.PHONY: k8s-setup
k8s-setup:
	@echo "Setting up local Kubernetes environment..."
	chmod +x scripts/setup-local-devops.sh
	./scripts/setup-local-devops.sh full

.PHONY: k8s-build
k8s-build:
	@echo "Building Docker images for Kubernetes..."
	docker build -t localhost:5000/uitgo/user-service:dev -f backend/user_service/Dockerfile .
	docker build -t localhost:5000/uitgo/trip-service:dev -f backend/trip_service/Dockerfile .
	docker build -t localhost:5000/uitgo/driver-service:dev -f backend/driver_service/Dockerfile .
	docker push localhost:5000/uitgo/user-service:dev
	docker push localhost:5000/uitgo/trip-service:dev
	docker push localhost:5000/uitgo/driver-service:dev
	@echo "Images built and pushed to local registry"

.PHONY: k8s-deploy
k8s-deploy:
	@echo "Deploying to Kubernetes (dev overlay)..."
	kubectl apply -k k8s/overlays/dev
	kubectl get pods -n uitgo

.PHONY: k8s-deploy-staging
k8s-deploy-staging:
	@echo "Deploying to Kubernetes (staging overlay)..."
	kubectl apply -k k8s/overlays/staging
	kubectl get pods -n uitgo

.PHONY: k8s-monitoring
k8s-monitoring:
	@echo "Deploying monitoring stack..."
	kubectl apply -k k8s/monitoring
	kubectl get pods -n monitoring

.PHONY: k8s-status
k8s-status:
	@echo "=== Nodes ==="
	kubectl get nodes
	@echo "\n=== UITGo Pods ==="
	kubectl get pods -n uitgo
	@echo "\n=== UITGo Services ==="
	kubectl get svc -n uitgo
	@echo "\n=== Monitoring Pods ==="
	kubectl get pods -n monitoring
	@echo "\n=== ArgoCD Apps ==="
	kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"

.PHONY: k8s-logs-user
k8s-logs-user:
	kubectl logs -n uitgo -l app=user-service --tail=100 -f

.PHONY: k8s-logs-trip
k8s-logs-trip:
	kubectl logs -n uitgo -l app=trip-service --tail=100 -f

.PHONY: k8s-logs-driver
k8s-logs-driver:
	kubectl logs -n uitgo -l app=driver-service --tail=100 -f

.PHONY: k8s-port-forward
k8s-port-forward:
	@echo "Starting port forwards..."
	@echo "API Gateway: http://localhost:8080"
	@echo "Grafana: http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward svc/user-service -n uitgo 8081:8081 &
	kubectl port-forward svc/trip-service -n uitgo 8082:8082 &
	kubectl port-forward svc/driver-service -n uitgo 8083:8083 &
	kubectl port-forward svc/grafana -n monitoring 3000:3000 &
	kubectl port-forward svc/prometheus -n monitoring 9090:9090 &
	wait

.PHONY: k8s-clean
k8s-clean:
	@echo "Cleaning up Kubernetes resources..."
	kubectl delete -k k8s/overlays/dev --ignore-not-found
	kubectl delete -k k8s/monitoring --ignore-not-found
	kubectl delete namespace uitgo --ignore-not-found
	kubectl delete namespace monitoring --ignore-not-found

.PHONY: k8s-restart
k8s-restart:
	@echo "Restarting all UITGo deployments..."
	kubectl rollout restart deployment -n uitgo

.PHONY: argocd-sync
argocd-sync:
	@echo "Syncing ArgoCD applications..."
	argocd app sync uitgo-dev

.PHONY: argocd-status
argocd-status:
	@echo "ArgoCD application status..."
	argocd app list
	argocd app get uitgo-dev

.PHONY: ci-local
ci-local:
	@echo "Running CI pipeline locally with Act..."
	act push -W .github/workflows/be_ci.yml

.PHONY: validate-manifests
validate-manifests:
	@echo "Validating Kubernetes manifests..."
	kustomize build k8s/base > /dev/null && echo "✓ Base manifests valid"
	kustomize build k8s/overlays/dev > /dev/null && echo "✓ Dev overlay valid"
	kustomize build k8s/overlays/staging > /dev/null && echo "✓ Staging overlay valid"

