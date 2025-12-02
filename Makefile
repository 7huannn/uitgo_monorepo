K6 ?= k6
API_BASE ?= http://localhost:8080
ACCESS_TOKEN ?=
LOADTEST_RESULTS_DIR := loadtests/results
TRIP_MATCHING_RESULT ?= $(LOADTEST_RESULTS_DIR)/trip_matching.json

.PHONY: loadtest-trip-matching
loadtest-trip-matching:
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "ACCESS_TOKEN is required (Bearer token for authenticated requests)"; \
		exit 1; \
	fi
	mkdir -p $(LOADTEST_RESULTS_DIR)
	API_BASE=$(API_BASE) ACCESS_TOKEN=$(ACCESS_TOKEN) $(K6) run --out json=$(TRIP_MATCHING_RESULT) loadtests/k6/trip_matching.js
	@echo "k6 results exported to $(TRIP_MATCHING_RESULT)"
