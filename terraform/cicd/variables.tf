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

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "AWS Secrets Manager secret name containing GitHub token"
  type        = string
}


variable "codestar_connection_arn" {
  description = "ARN of the AWS CodeStar connection for GitHub"
  type        = string
}
