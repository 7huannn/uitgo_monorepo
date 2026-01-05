resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnets"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Access to ${var.identifier} RDS"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # SECURITY: Restrict egress to only necessary destinations
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "Allow HTTPS for AWS services"
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier              = var.identifier
  engine                  = "postgres"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.this.id]
  publicly_accessible     = false
  
  # SECURITY: Enable encryption at rest
  storage_encrypted       = true
  kms_key_id              = var.kms_key_id
  
  # SECURITY: Enable automated backups
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  
  # SECURITY: Enable Multi-AZ for high availability (production)
  multi_az                = var.multi_az
  
  # SECURITY: Enable deletion protection for production
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"
  
  # SECURITY: Enable enhanced monitoring
  monitoring_interval     = var.monitoring_interval
  monitoring_role_arn     = var.monitoring_role_arn
  
  # SECURITY: Enable performance insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null
  
  # SECURITY: Enable IAM authentication
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  
  # SECURITY: Enable auto minor version upgrade
  auto_minor_version_upgrade = true
  
  # SECURITY: Copy tags to snapshots
  copy_tags_to_snapshot = true

  tags = var.tags
}
