variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "order_dlq_url" {
  description = "URL of the order DLQ"
  type        = string
}

variable "order_dlq_name" {
  description = "Name of the order DLQ"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function"
  type        = string
}

variable "lambda_function_names" {
  description = "List of Lambda function names"
  type        = list(string)
}

variable "api_gateway_id" {
  description = "ID of the API Gateway"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
}

variable "dlq_alert_threshold" {
  description = "Number of messages in DLQ to trigger alert"
  type        = number
  default     = 5
}
