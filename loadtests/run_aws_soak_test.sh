#!/bin/bash

# AWS Load Test Setup & Execution
# Waits for ALB to be healthy, then runs 90-minute soak test

set -e

AWS_API="http://uitgo-alb-2020541314.ap-southeast-1.elb.amazonaws.com"
MAX_RETRIES=20
RETRY_INTERVAL=30

echo "🚀 AWS Load Test - Automated Setup"
echo "=================================="
echo ""

# Function to check ALB health
check_health() {
    curl -s -o /dev/null -w "%{http_code}" "${AWS_API}/health" 2>/dev/null || echo "000"
}

# Wait for ALB to be healthy
echo "⏳ Waiting for AWS infrastructure to be ready..."
for i in $(seq 1 $MAX_RETRIES); do
    HTTP_CODE=$(check_health)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ ALB is healthy!"
        break
    fi
    
    echo "   Attempt $i/$MAX_RETRIES: HTTP $HTTP_CODE - Retrying in ${RETRY_INTERVAL}s..."
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo "❌ Failed to reach ALB after $MAX_RETRIES attempts"
        echo "   Check EC2 instances and Docker logs manually"
        exit 1
    fi
    
    sleep $RETRY_INTERVAL
done

echo ""
echo "📝 Setting up test user..."

# Register user
echo "1. Registering user..."
REGISTER_RESPONSE=$(curl -s -X POST ${AWS_API}/auth/register \
    -H "Content-Type: application/json" \
    -d '{"name":"AWS Test","email":"awstest@uitgo.com","password":"test123456","phone":"0900000001"}')

if echo "$REGISTER_RESPONSE" | grep -q "email"; then
    echo "   ✅ User registered successfully"
elif echo "$REGISTER_RESPONSE" | grep -q "already exists"; then
    echo "   ℹ️  User already exists, continuing..."
else
    echo "   ⚠️  Registration response: $REGISTER_RESPONSE"
fi

# Login
echo "2. Logging in..."
TOKEN=$(curl -s -X POST ${AWS_API}/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"awstest@uitgo.com","password":"test123456"}' | jq -r '.accessToken')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "   ❌ Failed to get access token"
    exit 1
fi

echo "   ✅ Got access token"

# Top-up wallet
echo "3. Topping up wallet..."
TOPUP_RESPONSE=$(curl -s -X POST ${AWS_API}/v1/wallet/topup \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"amount":10000000}')

if echo "$TOPUP_RESPONSE" | grep -q "balance"; then
    BALANCE=$(echo "$TOPUP_RESPONSE" | jq -r '.balance')
    echo "   ✅ Wallet balance: $BALANCE VND"
else
    echo "   ⚠️  Topup response: $TOPUP_RESPONSE"
fi

echo ""
echo "🎯 Starting 90-minute soak test..."
echo "   Base URL: $AWS_API"
echo "   RPS: 20"
echo "   VUs: 10"
echo "   Duration: 90 minutes"
echo "   Started at: $(date)"
echo "   Expected finish: $(date -d '+90 minutes' 2>/dev/null || date -v+90M)"
echo ""

# Export and run test
cd "$(dirname "$0")"
export ACCESS_TOKEN=$TOKEN
API_BASE=${AWS_API} SOAK_DURATION=90m STEADY_VUS=10 RPS=20 k6 run \
    --summary-export=results/aws_90min.json k6/soak_test.js

echo ""
echo "✅ AWS soak test completed!"
echo "Results saved to: results/aws_90min.json"
