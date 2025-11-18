resource "aws_db_instance" "this" {
  identifier                 = var.identifier
  replicate_source_db        = var.source_identifier
  instance_class             = var.instance_class
  publicly_accessible        = false
  apply_immediately          = true
  auto_minor_version_upgrade = true
  availability_zone          = var.availability_zone
  tags                       = var.tags
}

output "endpoint" {
  value = aws_db_instance.this.address
}

output "identifier" {
  value = aws_db_instance.this.id
}
