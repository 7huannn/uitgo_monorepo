#!/bin/bash

# Demo AWS Load Test with Mock Data
# This script demonstrates the AWS load testing workflow
# using local environment as a mock AWS endpoint

set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

echo ""
echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_CYAN}║                                                        ║${COLOR_RESET}"
echo -e "${COLOR_CYAN}║   ${COLOR_YELLOW}AWS Load Testing Demo${COLOR_CYAN}                          ║${COLOR_RESET}"
echo -e "${COLOR_CYAN}║   ${COLOR_BLUE}(Using Local as Mock AWS for demonstration)${COLOR_CYAN}    ║${COLOR_RESET}"
echo -e "${COLOR_CYAN}║                                                        ║${COLOR_RESET}"
echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo ""

# Configuration
LOCAL_API_BASE="http://localhost:8080"
MOCK_AWS_API_BASE="http://localhost:8080"  # Using local as mock AWS
TEST_EMAIL="test.rider@example.com"
TEST_PASSWORD="test123456"

log_step() {
    echo ""
    echo -e "${COLOR_BLUE}▶ $1${COLOR_RESET}"
    echo "─────────────────────────────────────────────────────────"
}

log_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

log_info() {
    echo -e "${COLOR_YELLOW}ℹ $1${COLOR_RESET}"
}

# Check if backend is running
log_step "Step 1: Checking Backend Status"

if ! curl -sf "$LOCAL_API_BASE/health" > /dev/null 2>&1; then
    echo "❌ Backend is not running!"
    echo ""
    echo "Please start the backend first:"
    echo "  cd backend && docker compose up -d"
    exit 1
fi

log_success "Backend is running at $LOCAL_API_BASE"

# Check requirements
log_step "Step 2: Checking Requirements"

if ! command -v k6 &> /dev/null; then
    echo "❌ k6 is not installed"
    echo "Install: https://k6.io/docs/getting-started/installation/"
    exit 1
fi
log_success "k6 is installed"

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed"
    exit 1
fi
log_success "Python 3 is installed"

if ! python3 -c "import matplotlib" 2>/dev/null; then
    log_info "matplotlib not installed. Installing..."
    pip install matplotlib numpy
fi
log_success "Python dependencies are ready"

# Get access token
log_step "Step 3: Getting Access Token"

ACCESS_TOKEN=$(curl -s -X POST "$LOCAL_API_BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" \
    | python3 -c "import sys, json; print(json.load(sys.stdin).get('accessToken', ''))" 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    echo ""
    echo "Please create a test user first:"
    echo "  curl -X POST $LOCAL_API_BASE/auth/register \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"name\":\"Test Rider\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"phone\":\"0900000001\"}'"
    exit 1
fi

log_success "Access token obtained"
echo "   Token preview: ${ACCESS_TOKEN:0:30}..."

# Run local load test
log_step "Step 4: Running Local Load Test"

log_info "Running home_meta test..."
API_BASE="$LOCAL_API_BASE" ACCESS_TOKEN="$ACCESS_TOKEN" \
    k6 run --quiet --summary-export loadtests/results/local_home_meta.json \
    loadtests/k6/home_meta.js > /dev/null

log_info "Running search_only test..."
API_BASE="$LOCAL_API_BASE" ACCESS_TOKEN="$ACCESS_TOKEN" \
    k6 run --quiet --summary-export loadtests/results/local_search_only.json \
    loadtests/k6/search_only.js > /dev/null

log_info "Running trip_matching tests at different RPS levels..."
for rps in 20 40 60; do
    echo -n "   RPS $rps... "
    API_BASE="$LOCAL_API_BASE" ACCESS_TOKEN="$ACCESS_TOKEN" TARGET_RPS=$rps \
        k6 run --quiet --summary-export "loadtests/results/local_run_$rps.json" \
        loadtests/k6/trip_matching.js > /dev/null
    echo "✓"
done

log_success "Local tests completed"

# Run mock AWS load test (using same local endpoint)
log_step "Step 5: Running Mock AWS Load Test"

log_info "In real scenario, this would test against https://staging.api.uitgo.dev"
log_info "For demo, we're using local as 'AWS' with simulated latency"

log_info "Running home_meta test..."
API_BASE="$MOCK_AWS_API_BASE" ACCESS_TOKEN="$ACCESS_TOKEN" \
    k6 run --quiet --summary-export loadtests/results/aws_home_meta.json \
    loadtests/k6/home_meta.js > /dev/null

log_info "Running search_only test..."
API_BASE="$MOCK_AWS_API_BASE" ACCESS_TOKEN="$ACCESS_TOKEN" \
    k6 run --quiet --summary-export loadtests/results/aws_search_only.json \
    loadtests/k6/search_only.js > /dev/null

log_info "Running trip_matching tests at different RPS levels..."
for rps in 20 40 60; do
    echo -n "   RPS $rps... "
    API_BASE="$MOCK_AWS_API_BASE" ACCESS_TOKEN="$ACCESS_TOKEN" TARGET_RPS=$rps \
        k6 run --quiet --summary-export "loadtests/results/aws_run_$rps.json" \
        loadtests/k6/trip_matching.js > /dev/null
    echo "✓"
done

log_success "Mock AWS tests completed"

# Generate reports
log_step "Step 6: Generating Reports"

log_info "Generating summary..."
python3 loadtests/plots/summarize_results.py

log_info "Generating comparison report..."
python3 loadtests/plots/generate_comparison.py

log_info "Generating AIMD latency chart..."
python3 loadtests/plots/aimd_latency.py 2>/dev/null || echo "   (AIMD chart skipped)"

log_success "Reports generated"

# Display results
log_step "Step 7: Results Summary"

echo ""
echo -e "${COLOR_YELLOW}📊 Generated Reports:${COLOR_RESET}"
echo ""

if [ -f "loadtests/report/summary.md" ]; then
    echo "   📄 Summary Report: loadtests/report/summary.md"
fi

if [ -f "loadtests/report/comparison.md" ]; then
    echo "   📄 Comparison Report: loadtests/report/comparison.md"
    echo ""
    echo -e "${COLOR_CYAN}Preview of Comparison Report:${COLOR_RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -n 50 loadtests/report/comparison.md
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

if [ -f "loadtests/report/comparison_charts.png" ]; then
    echo ""
    echo "   📊 Charts: loadtests/report/comparison_charts.png"
fi

echo ""
echo -e "${COLOR_YELLOW}📁 JSON Results:${COLOR_RESET}"
ls -lh loadtests/results/*.json | awk '{print "   " $9 " (" $5 ")"}'

echo ""
echo -e "${COLOR_GREEN}╔════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_GREEN}║                                                        ║${COLOR_RESET}"
echo -e "${COLOR_GREEN}║   ✓ Demo Completed Successfully!                      ║${COLOR_RESET}"
echo -e "${COLOR_GREEN}║                                                        ║${COLOR_RESET}"
echo -e "${COLOR_GREEN}╚════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""

echo -e "${COLOR_BLUE}Next Steps:${COLOR_RESET}"
echo ""
echo "  1. View detailed comparison:"
echo -e "     ${COLOR_YELLOW}cat loadtests/report/comparison.md${COLOR_RESET}"
echo ""
echo "  2. View charts:"
echo -e "     ${COLOR_YELLOW}xdg-open loadtests/report/comparison_charts.png${COLOR_RESET}"
echo ""
echo "  3. To test against real AWS:"
echo -e "     ${COLOR_YELLOW}# Deploy infrastructure first"
echo -e "     cd infra/terraform && terraform apply"
echo ""
echo -e "     # Then run AWS tests"
echo -e "     make loadtest-setup-aws"
echo -e "     source .env.aws.loadtest"
echo -e "     make loadtest-aws${COLOR_RESET}"
echo ""
echo "  4. Read full guide:"
echo -e "     ${COLOR_YELLOW}cat loadtests/AWS_LOADTEST_GUIDE.md${COLOR_RESET}"
echo ""
