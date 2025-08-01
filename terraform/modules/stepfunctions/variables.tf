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

variable "validator_lambda_arn" {
  description = "ARN of the validator Lambda function"
  type        = string
}

variable "order_storage_lambda_arn" {
  description = "ARN of the order storage Lambda function"
  type        = string
}

variable "order_queue_url" {
  description = "URL of the order SQS queue"
  type        = string
}
