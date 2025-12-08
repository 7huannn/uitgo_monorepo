# Required
aws_region        = "ap-southeast-1"
db_password       = "***REMOVED***"
trip_service_ami  = "ami-093a7f5fbae13ff67"                # AMI with docker + compose plugin
container_registry = "ghcr.io/7huannn"              # or your ECR repo
backend_image_tag  = "latest"                     # tag pushed for user/trip/driver

# Secrets
jwt_secret                   = "replace-with-strong-jwt-secret"
refresh_token_encryption_key = "refresh-token-enc-key-32-bytes!!"
internal_api_key             = "internal-api-key-change-me"

# CORS / HTTPS
cors_allowed_origins = "*"
alb_certificate_arn  = ""                         # set ACM ARN to enable HTTPS
