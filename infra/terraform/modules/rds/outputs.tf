output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.address
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "identifier" {
  description = "RDS instance identifier for replica"
  value       = aws_db_instance.this.identifier
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}
