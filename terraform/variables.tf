variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dofs"
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
  default     = "debabratamohapatra47@gmail.com"
}

variable "github_repo_url" {
  description = "GitHub repository URL for CodePipeline"
  type        = string
  default     = "https://github.com/debabrata47/dofs-project"
}

variable "github_branch" {
  description = "GitHub branch for CodePipeline"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "AWS Secrets Manager secret name containing GitHub token"
  type        = string
  default     = "github-token"
}

variable "enable_dlq_alerting" {
  description = "Enable DLQ depth alerting"
  type        = bool
  default     = true
}

variable "dlq_alert_threshold" {
  description = "Number of messages in DLQ to trigger alert"
  type        = number
  default     = 5
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

variable "sqs_visibility_timeout" {
  description = "SQS queue visibility timeout in seconds"
  type        = number
  default     = 180
}

variable "sqs_max_receive_count" {
  description = "Maximum number of times a message can be received before being sent to DLQ"
  type        = number
  default     = 3
}

variable "deploy_cicd_pipeline" {
  description = "Whether to deploy the CI/CD pipeline"
  type        = bool
  default     = true
}
