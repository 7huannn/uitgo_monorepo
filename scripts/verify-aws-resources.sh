#!/bin/bash
# Verify AWS resources for video demo
# This helps you confirm everything is deployed before recording

set -e

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
PROJECT="uitgo"

echo "🔍 Verifying AWS resources for demo..."
echo "Region: $AWS_REGION"
echo ""

# Function to print section header
print_section() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════════"
}

# Check AWS CLI
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI not found. Please install it first."
  exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ AWS credentials not configured or expired."
  echo "Run: aws configure"
  exit 1
fi

echo "✅ AWS CLI configured"
echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo ""

# Auto Scaling Groups
print_section "AUTO SCALING GROUPS"
echo "Checking for ASGs with prefix: $PROJECT..."
ASG_COUNT=$(aws autoscaling describe-auto-scaling-groups \
  --region $AWS_REGION \
  --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '${PROJECT}')].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Current:length(Instances),Status:Status}" \
  --output table | tee /dev/tty | grep -c "$PROJECT" || echo "0")

if [ "$ASG_COUNT" -gt 0 ]; then
  echo "✅ Found $ASG_COUNT Auto Scaling Group(s)"
else
  echo "⚠️  No Auto Scaling Groups found"
fi

# RDS Databases
print_section "RDS DATABASES"
echo "Checking for RDS instances with prefix: $PROJECT..."
RDS_COUNT=$(aws rds describe-db-instances \
  --region $AWS_REGION \
  --query "DBInstances[?starts_with(DBInstanceIdentifier, '${PROJECT}')].{Name:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass,Storage:AllocatedStorage}" \
  --output table | tee /dev/tty | grep -c "$PROJECT" || echo "0")

if [ "$RDS_COUNT" -gt 0 ]; then
  echo "✅ Found $RDS_COUNT RDS instance(s)"
else
  echo "⚠️  No RDS instances found"
fi

# ElastiCache Redis
print_section "ELASTICACHE REDIS"
echo "Checking for Redis clusters with prefix: $PROJECT..."
REDIS_COUNT=$(aws elasticache describe-cache-clusters \
  --region $AWS_REGION \
  --query "CacheClusters[?starts_with(CacheClusterId, '${PROJECT}')].{Name:CacheClusterId,Status:CacheClusterStatus,Engine:Engine,NodeType:CacheNodeType}" \
  --output table | tee /dev/tty | grep -c "$PROJECT" || echo "0")

if [ "$REDIS_COUNT" -gt 0 ]; then
  echo "✅ Found $REDIS_COUNT Redis cluster(s)"
else
  echo "⚠️  No Redis clusters found"
fi

# VPC
print_section "VPC"
echo "Checking for VPC with prefix: $PROJECT..."
VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT}*" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "✅ Found VPC: $VPC_ID"
  
  # Subnets
  SUBNET_COUNT=$(aws ec2 describe-subnets \
    --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "length(Subnets)" \
    --output text)
  echo "   └─ Subnets: $SUBNET_COUNT"
  
  # Security Groups
  SG_COUNT=$(aws ec2 describe-security-groups \
    --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "length(SecurityGroups)" \
    --output text)
  echo "   └─ Security Groups: $SG_COUNT"
else
  echo "⚠️  No VPC found"
fi

# S3 Buckets (optional)
print_section "S3 BUCKETS"
echo "Checking for S3 buckets with prefix: $PROJECT..."
S3_BUCKETS=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, '${PROJECT}')].Name" \
  --output text)

if [ -n "$S3_BUCKETS" ]; then
  echo "✅ Found S3 bucket(s):"
  for bucket in $S3_BUCKETS; do
    echo "   • $bucket"
  done
else
  echo "⚠️  No S3 buckets found with prefix '$PROJECT'"
fi

# Load Balancers (if any)
print_section "LOAD BALANCERS"
echo "Checking for Load Balancers with prefix: $PROJECT..."
ALB_COUNT=$(aws elbv2 describe-load-balancers \
  --region $AWS_REGION \
  --query "LoadBalancers[?starts_with(LoadBalancerName, '${PROJECT}')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table 2>/dev/null | grep -c "$PROJECT" || echo "0")

if [ "$ALB_COUNT" -gt 0 ]; then
  echo "✅ Found $ALB_COUNT Load Balancer(s)"
else
  echo "ℹ️  No Load Balancers found (might not be deployed)"
fi

# Summary
print_section "SUMMARY"
echo "Resources ready for demo:"
echo "  • Auto Scaling Groups: $([ "$ASG_COUNT" -gt 0 ] && echo "✅" || echo "❌") ($ASG_COUNT)"
echo "  • RDS Databases: $([ "$RDS_COUNT" -gt 0 ] && echo "✅" || echo "❌") ($RDS_COUNT)"
echo "  • Redis Clusters: $([ "$REDIS_COUNT" -gt 0 ] && echo "✅" || echo "❌") ($REDIS_COUNT)"
echo "  • VPC: $([ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ] && echo "✅" || echo "❌")"
echo ""

TOTAL_RESOURCES=$((ASG_COUNT + RDS_COUNT + REDIS_COUNT))
if [ "$TOTAL_RESOURCES" -gt 0 ]; then
  echo "🎉 Total: $TOTAL_RESOURCES resources found"
  echo "✅ Ready to open AWS Console for demo!"
  echo ""
  echo "Run: ./scripts/open-aws-console-tabs.sh"
else
  echo "⚠️  No resources found. Have you run terraform apply?"
  echo ""
  echo "To deploy infrastructure:"
  echo "  cd infra/terraform/envs/dev"
  echo "  terraform init"
  echo "  terraform apply"
fi

echo ""
