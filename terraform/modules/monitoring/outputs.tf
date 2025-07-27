output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main_dashboard.dashboard_name}"
}

output "dlq_alarm_arn" {
  description = "ARN of the DLQ CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.dlq_message_count.arn
}

output "step_function_alarm_arn" {
  description = "ARN of the Step Function CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.step_function_failures.arn
}
