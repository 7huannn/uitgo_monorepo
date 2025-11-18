terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project = var.project
    Env     = "dev"
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

module "driver_service_asg" {
  source             = "../../modules/asg_service"
  name               = "${var.project}-driver"
  ami_id             = var.driver_service_ami
  security_group_ids = [aws_security_group.services.id]
  subnet_ids         = module.network.private_subnet_ids
  tags               = merge(local.tags, { Service = "driver" })
}

module "trip_service_asg" {
  source             = "../../modules/asg_service"
  name               = "${var.project}-trip"
  ami_id             = var.trip_service_ami
  security_group_ids = [aws_security_group.services.id]
  subnet_ids         = module.network.private_subnet_ids
  tags               = merge(local.tags, { Service = "trip" })
}

resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = toset(["api", "user", "driver", "trip"])

  name              = "/${var.project}/${local.tags.Env}/${each.key}"
  retention_in_days = 30
  tags              = merge(local.tags, { Service = each.key })
}
