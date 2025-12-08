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

.PHONY: loadtest-all
loadtest-all: loadtest-local loadtest-aws loadtest-summarize loadtest-plot

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
