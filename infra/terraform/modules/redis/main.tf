resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-subnets"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Access to ${var.name} redis"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id        = replace(var.name, "_", "-")
  description                 = "${var.name} driver geo index"
  engine                      = "redis"
  engine_version              = var.engine_version
  node_type                   = var.node_type
  parameter_group_name        = var.parameter_group_name
  port                        = var.port
  automatic_failover_enabled  = false
  multi_az_enabled            = false
  number_cache_clusters       = var.cluster_count
  transit_encryption_enabled  = true
  at_rest_encryption_enabled  = true
  subnet_group_name           = aws_elasticache_subnet_group.this.name
  security_group_ids          = [aws_security_group.this.id]
  apply_immediately           = true
  maintenance_window          = var.maintenance_window
  final_snapshot_identifier   = "${var.name}-final"
  snapshot_retention_limit    = 0
  auth_token                  = var.auth_token
  preferred_cache_cluster_azs = var.preferred_azs
  notification_topic_arn      = var.notification_topic_arn
  auto_minor_version_upgrade  = true
  data_tiering_enabled        = false

  lifecycle {
    ignore_changes = [auth_token]
  }

  tags = var.tags
}
