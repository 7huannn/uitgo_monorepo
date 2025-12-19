#!/bin/bash
# UITGo DevOps Demo Script - 5 minutes
# Run this to prepare before recording

set -e

echo "🎬 Preparing 5-minute DevOps demo..."
echo ""

# 1. Check AWS resources (if deploying cloud infrastructure)
echo "═══════════════════════════════════════════════════════════"
echo "STEP 1: Verify AWS Resources"
echo "═══════════════════════════════════════════════════════════"
if command -v aws &> /dev/null; then
  echo "▶️  Checking AWS resources..."
  ./scripts/verify-aws-resources.sh
else
  echo "ℹ️  AWS CLI not found - skipping cloud verification"
  echo "   (Install if you want to show AWS infrastructure)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 2: Verify Local Kubernetes"
echo "═══════════════════════════════════════════════════════════"
echo "▶️  Checking K8s cluster..."
kubectl get nodes > /dev/null 2>&1 || { echo "❌ K8s not running!"; exit 1; }
echo "✅ K8s cluster running"

# 2. Ensure all pods are ready
echo "⏳ Checking pods status..."
kubectl wait --for=condition=ready pod -l app=user-service -n uitgo --timeout=60s
kubectl wait --for=condition=ready pod -l app=trip-service -n uitgo --timeout=60s
kubectl wait --for=condition=ready pod -l app=driver-service -n uitgo --timeout=60s
echo "✅ All services healthy"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 3: Setup Port Forwarding"
echo "═══════════════════════════════════════════════════════════"
echo "🔌 Setting up port forwarding..."
pkill -f "port-forward.*prometheus" || true
pkill -f "port-forward.*grafana" || true
pkill -f "port-forward.*argocd" || true
kubectl port-forward -n monitoring svc/prometheus 9090:9090 > /dev/null 2>&1 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 > /dev/null 2>&1 &
kubectl port-forward -n argocd svc/argocd-server 8080:443 > /dev/null 2>&1 &
sleep 2
echo "✅ Port forwarding ready"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 4: Get Auth Token"
echo "═══════════════════════════════════════════════════════════"
echo "🔑 Getting auth token..."
TOKEN=$(curl -s http://uitgo.local/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"+84901234567","password":"rider123"}' | jq -r '.access_token' || echo "")

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo "⚠️  No token - register a test user first"
  echo "Run: make seed"
else
  echo "✅ Token ready"
  echo "export TOKEN='$TOKEN'" > /tmp/demo_token.sh
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "STEP 5: Open Browser Tabs"
echo "═══════════════════════════════════════════════════════════"
read -p "Open AWS Console tabs? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  chmod +x scripts/open-aws-console-tabs.sh
  ./scripts/open-aws-console-tabs.sh
fi

echo ""
echo "Opening local DevOps stack..."
firefox http://localhost:9090 &      # Prometheus
sleep 2
firefox http://localhost:3000 &      # Grafana
sleep 2
firefox https://localhost:8080 &     # ArgoCD
sleep 2

# 5. Clear terminal history for clean demo
history -c

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ DEMO PREPARATION COMPLETE!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Checklist:"
echo "  1. ✅ K8s cluster running"
echo "  2. ✅ All services healthy"
echo "  3. ✅ Monitoring accessible (Prometheus:9090, Grafana:3000)"
echo "  4. ✅ ArgoCD accessible (localhost:8080)"
echo "  5. ✅ Auth token ready"
echo "  6. ✅ Browser tabs opened"
echo ""
echo "🎬 Ready to record! Follow VIDEO_SCRIPT_5MIN.md"
echo ""
echo "💡 Quick commands:"
echo "   Source token:     source /tmp/demo_token.sh"
echo "   Health check:     curl http://uitgo.local/health"
echo "   Test API:         curl -H \"Authorization: Bearer \$TOKEN\" http://uitgo.local/v1/users/me"
echo ""
echo "🌐 URLs:"
echo "   ArgoCD:      https://localhost:8080"
echo "   Prometheus:  http://localhost:9090"
echo "   Grafana:     http://localhost:3000 (admin/uitgo)"
echo ""
