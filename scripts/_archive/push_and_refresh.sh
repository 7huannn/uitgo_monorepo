#!/bin/bash

# Push Docker images to GHCR and force ASG refresh (archived)
set -e

TAG=${1:-v0.1.0}
REG=ghcr.io/7huannn

echo "🚀 Pushing images to GHCR..."
echo "Tag: $TAG"
echo ""

# Check if logged in to GHCR
if ! docker info 2>/dev/null | grep -q "ghcr.io"; then
    echo "⚠️  Not logged in to GHCR. Attempting login..."
    echo "Please enter your GitHub Personal Access Token (with packages:write permission):"
    read -s GITHUB_TOKEN
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u 7huannn --password-stdin
fi

# Push images
echo "1. Pushing user-service..."
docker push $REG/uitgo-user-service:$TAG

echo "2. Pushing trip-service..."
docker push $REG/uitgo-trip-service:$TAG

echo "3. Pushing driver-service..."
docker push $REG/uitgo-driver-service:$TAG

echo ""
echo "✅ All images pushed successfully!"
echo ""

# Force ASG instance refresh
echo "🔄 Refreshing ASG instances to pull new images..."
AWS_REGION=ap-southeast-1 aws autoscaling start-instance-refresh \
    --auto-scaling-group-name uitgo-trip-asg \
    --preferences '{
        "MinHealthyPercentage": 50,
        "InstanceWarmup": 300
    }'

echo ""
echo "✅ Instance refresh started!"
echo "⏳ This will take about 5-10 minutes..."
echo ""
echo "Monitor progress with:"
echo "  watch -n 10 'AWS_REGION=ap-southeast-1 aws autoscaling describe-instance-refreshes --auto-scaling-group-name uitgo-trip-asg --query \"InstanceRefreshes[0].[Status,PercentageComplete]\" --output text'"
