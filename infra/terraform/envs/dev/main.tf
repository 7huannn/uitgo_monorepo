terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_password" "driver_cache_auth_token" {
  length  = 32
  special = true
}

locals {
  tags = {
    Project = var.project
    Env     = "dev"
  }
  backend_port       = 8080
  backend_stack_name = "${var.project}-backend"
  backend_images = {
    user   = "${var.container_registry}/uitgo-user-service:${var.backend_image_tag}"
    trip   = "${var.container_registry}/uitgo-trip-service:${var.backend_image_tag}"
    driver = "${var.container_registry}/uitgo-driver-service:${var.backend_image_tag}"
  }
}

module "network" {
  source               = "../../modules/network"
  name                 = var.project
  cidr_block           = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnets
  private_subnet_cidrs = var.private_subnets
  tags                 = local.tags
}

module "user_db" {
  source        = "../../modules/rds"
  identifier    = "${var.project}-user-db"
  db_name       = "user_service"
  username      = var.db_username
  password      = var.db_password
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.private_subnet_ids
  allowed_cidrs = [module.network.cidr_block]
  tags          = merge(local.tags, { Service = "user" })
}

module "trip_db" {
  source        = "../../modules/rds"
  identifier    = "${var.project}-trip-db"
  db_name       = "trip_service"
  username      = var.db_username
  password      = var.db_password
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.private_subnet_ids
  allowed_cidrs = [module.network.cidr_block]
  tags          = merge(local.tags, { Service = "trip" })
}

module "driver_db" {
  source        = "../../modules/rds"
  identifier    = "${var.project}-driver-db"
  db_name       = "driver_service"
  username      = var.db_username
  password      = var.db_password
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.private_subnet_ids
  allowed_cidrs = [module.network.cidr_block]
  tags          = merge(local.tags, { Service = "driver" })
}

module "driver_cache" {
  source        = "../../modules/redis"
  name          = "${var.project}-driver-cache"
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.private_subnet_ids
  allowed_cidrs = [module.network.cidr_block]
  tags          = merge(local.tags, { Service = "driver" })
  auth_token    = random_password.driver_cache_auth_token.result
}

resource "aws_security_group" "services" {
  name        = "${var.project}-services"
  description = "Allow east-west service traffic"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.network.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb"
  description = "Internet facing access to ${var.project} backend"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "alb" })
}

resource "aws_lb" "api" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.network.public_subnet_ids
  idle_timeout       = 60
  enable_deletion_protection = false

  tags = merge(local.tags, { Component = "alb" })
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project}-api"
  port        = local.backend_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.network.vpc_id

  health_check {
    path                = "/health"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
    timeout             = 5
  }

  tags = merge(local.tags, { Component = "alb" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener" "https" {
  count             = var.alb_certificate_arn == "" ? 0 : 1
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.alb_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

module "trip_match_queue" {
  source = "../../modules/sqs"
  name   = "${var.project}-trip-match"
  tags   = merge(local.tags, { Service = "trip" })
}

module "trip_db_replica" {
  source            = "../../modules/rds_replica"
  identifier        = "${var.project}-trip-replica"
  source_identifier = module.trip_db.identifier
  availability_zone = element(var.availability_zones, 0)
  tags              = merge(local.tags, { Service = "trip" })
}

locals {
  backend_env = {
    user_db_dsn   = format("postgres://%s:%s@%s:5432/%s?sslmode=disable", var.db_username, var.db_password, module.user_db.endpoint, "user_service")
    trip_db_dsn   = format("postgres://%s:%s@%s:5432/%s?sslmode=disable", var.db_username, var.db_password, module.trip_db.endpoint, "trip_service")
    trip_db_replica_dsn = format("postgres://%s:%s@%s:5432/%s?sslmode=disable", var.db_username, var.db_password, module.trip_db_replica.endpoint, "trip_service")
    driver_db_dsn = format("postgres://%s:%s@%s:5432/%s?sslmode=disable", var.db_username, var.db_password, module.driver_db.endpoint, "driver_service")
    redis_addr    = format("%s:%d", module.driver_cache.primary_endpoint, module.driver_cache.port)
    redis_password = random_password.driver_cache_auth_token.result
    sqs_queue_url = module.trip_match_queue.url
  }

  backend_user_data = templatefile("${path.module}/user_data/backend.sh.tpl", {
    project_name          = local.backend_stack_name
    aws_region            = var.aws_region
    user_service_image    = local.backend_images.user
    trip_service_image    = local.backend_images.trip
    driver_service_image  = local.backend_images.driver
    user_db_dsn           = local.backend_env.user_db_dsn
    trip_db_dsn           = local.backend_env.trip_db_dsn
    trip_db_replica_dsn   = local.backend_env.trip_db_replica_dsn
    driver_db_dsn         = local.backend_env.driver_db_dsn
    redis_addr            = local.backend_env.redis_addr
    redis_password        = local.backend_env.redis_password
    sqs_queue_url         = local.backend_env.sqs_queue_url
    cors_allowed_origins  = var.cors_allowed_origins
    jwt_secret            = var.jwt_secret
    refresh_token_key     = var.refresh_token_encryption_key
    internal_api_key      = var.internal_api_key
    backend_port          = local.backend_port
    match_queue_name      = "trip:requests"
  })
}

module "trip_service_asg" {
  source             = "../../modules/asg_service"
  name               = "${var.project}-trip"
  ami_id             = var.trip_service_ami
  security_group_ids = [aws_security_group.services.id]
  subnet_ids         = module.network.private_subnet_ids
  user_data          = local.backend_user_data
  tags               = merge(local.tags, { Service = "trip" })
}

resource "aws_autoscaling_attachment" "trip_service" {
  autoscaling_group_name = module.trip_service_asg.asg_name
  lb_target_group_arn    = aws_lb_target_group.api.arn
}

resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = toset(["api", "user", "driver", "trip"])

  name              = "/${var.project}/${local.tags.Env}/${each.key}"
  retention_in_days = 30
  tags              = merge(local.tags, { Service = each.key })
}
