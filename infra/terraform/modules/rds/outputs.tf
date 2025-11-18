output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.address
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "identifier" {
  value = aws_db_instance.this.id
}
