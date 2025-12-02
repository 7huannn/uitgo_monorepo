resource "aws_sqs_queue" "this" {
  name                              = var.name
  visibility_timeout_seconds        = var.visibility_timeout
  message_retention_seconds         = var.retention_seconds
  max_message_size                  = var.max_message_size
  fifo_queue                        = var.fifo
  content_based_deduplication       = var.fifo
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_seconds
  receive_wait_time_seconds         = var.receive_wait_time
  redrive_policy = var.dead_letter_queue_arn == "" ? null : jsonencode({
    deadLetterTargetArn = var.dead_letter_queue_arn
    maxReceiveCount     = var.max_receive_count
  })
  tags = var.tags
}

output "arn" {
  value = aws_sqs_queue.this.arn
}

output "url" {
  value = aws_sqs_queue.this.id
}
