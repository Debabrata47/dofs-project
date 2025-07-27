output "order_queue_url" {
  description = "URL of the order SQS queue"
  value       = aws_sqs_queue.order_queue.url
}

output "order_queue_arn" {
  description = "ARN of the order SQS queue"
  value       = aws_sqs_queue.order_queue.arn
}

output "order_queue_name" {
  description = "Name of the order SQS queue"
  value       = aws_sqs_queue.order_queue.name
}

output "order_dlq_url" {
  description = "URL of the order DLQ"
  value       = aws_sqs_queue.order_dlq.url
}

output "order_dlq_arn" {
  description = "ARN of the order DLQ"
  value       = aws_sqs_queue.order_dlq.arn
}

output "order_dlq_name" {
  description = "Name of the order DLQ"
  value       = aws_sqs_queue.order_dlq.name
}
