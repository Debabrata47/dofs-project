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

variable "api_handler_lambda_arn" {
  description = "ARN of the API handler Lambda function"
  type        = string
}

variable "api_handler_lambda_function_name" {
  description = "Name of the API handler Lambda function"
  type        = string
}
