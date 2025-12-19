#!/bin/bash
# Open AWS Console tabs for video demo
# Make sure you're logged in to AWS Console before running this

AWS_REGION="ap-southeast-1"
PROJECT_PREFIX="uitgo"

echo "🌐 Opening AWS Console tabs for demo..."
echo "Region: $AWS_REGION"
echo ""

# Wait time between opening tabs to avoid browser overwhelm
WAIT_TIME=2

# EC2 Auto Scaling Groups
echo "▶️  Opening EC2 Auto Scaling Groups..."
firefox "https://${AWS_REGION}.console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#AutoScalingGroups:" &
sleep $WAIT_TIME

# RDS Databases
echo "▶️  Opening RDS Databases..."
firefox "https://${AWS_REGION}.console.aws.amazon.com/rds/home?region=${AWS_REGION}#databases:" &
sleep $WAIT_TIME

# ElastiCache Redis
echo "▶️  Opening ElastiCache Redis..."
firefox "https://${AWS_REGION}.console.aws.amazon.com/elasticache/home?region=${AWS_REGION}#/redis" &
sleep $WAIT_TIME

# VPC
echo "▶️  Opening VPC Dashboard..."
firefox "https://${AWS_REGION}.console.aws.amazon.com/vpc/home?region=${AWS_REGION}#vpcs:" &
sleep $WAIT_TIME

# S3 Buckets
echo "▶️  Opening S3 Buckets..."
firefox "https://s3.console.aws.amazon.com/s3/buckets?region=${AWS_REGION}" &
sleep $WAIT_TIME

# CloudWatch (optional)
# echo "▶️  Opening CloudWatch..."
# firefox "https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}" &

echo ""
echo "✅ All AWS Console tabs opened!"
echo ""
echo "📋 Next steps:"
echo "  1. Login to AWS Console if prompted"
echo "  2. In each tab, search/filter for '${PROJECT_PREFIX}' resources"
echo "  3. Arrange tabs in order: ASG → RDS → ElastiCache → VPC → S3"
echo "  4. Ready for recording!"
echo ""
echo "💡 To show specific resources:"
echo "   - ASG: ${PROJECT_PREFIX}-user-asg, ${PROJECT_PREFIX}-trip-asg, ${PROJECT_PREFIX}-driver-asg"
echo "   - RDS: ${PROJECT_PREFIX}-user-db, ${PROJECT_PREFIX}-trip-db, ${PROJECT_PREFIX}-driver-db"
echo "   - Redis: ${PROJECT_PREFIX}-driver-cache"
echo "   - VPC: ${PROJECT_PREFIX}"
