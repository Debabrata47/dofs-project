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

variable "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  type        = string
}

variable "orders_table_arn" {
  description = "ARN of the orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_name" {
  description = "Name of the failed orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_arn" {
  description = "ARN of the failed orders DynamoDB table"
  type        = string
}

variable "order_queue_url" {
  description = "URL of the order SQS queue"
  type        = string
}

variable "order_queue_arn" {
  description = "ARN of the order SQS queue"
  type        = string
}

variable "order_dlq_url" {
  description = "URL of the order DLQ"
  type        = string
}

variable "order_dlq_arn" {
  description = "ARN of the order DLQ"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function"
  type        = string
  default     = ""
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "max_receive_count" {
  description = "Maximum number of times a message can be received before being sent to DLQ"
  type        = number
  default     = 3
}
