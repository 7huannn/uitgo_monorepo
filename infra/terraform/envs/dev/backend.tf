# S3 Backend Configuration for Terraform State
# This enables remote state management for team collaboration and CI/CD
#
# Prerequisites:
#   1. Create S3 bucket: aws s3 mb s3://uitgo-terraform-state --region ap-southeast-1
#   2. Enable versioning: aws s3api put-bucket-versioning --bucket uitgo-terraform-state --versioning-configuration Status=Enabled
#   3. Create DynamoDB table for locking:
#      aws dynamodb create-table \
#        --table-name uitgo-terraform-locks \
#        --attribute-definitions AttributeName=LockID,AttributeType=S \
#        --key-schema AttributeName=LockID,KeyType=HASH \
#        --billing-mode PAY_PER_REQUEST \
#        --region ap-southeast-1
#   4. Add to GitHub Secrets:
#      - TF_STATE_BUCKET: uitgo-terraform-state
#      - TF_LOCK_TABLE: uitgo-terraform-locks
#
# For local development, init with:
#   terraform init \
#     -backend-config="bucket=uitgo-terraform-state" \
#     -backend-config="key=uitgo/dev/terraform.tfstate" \
#     -backend-config="region=ap-southeast-1" \
#     -backend-config="dynamodb_table=uitgo-terraform-locks"

terraform {
  backend "s3" {
    # Values provided via -backend-config flags or environment
    # bucket         = "uitgo-terraform-state"
    # key            = "uitgo/dev/terraform.tfstate"
    # region         = "ap-southeast-1"
    # dynamodb_table = "uitgo-terraform-locks"
    encrypt        = true
  }
}
