terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# DynamoDB Tables
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = local.common_tags
}

# SQS Queues
module "sqs" {
  source = "./modules/sqs"
  
  project_name = var.project_name
  environment  = var.environment
  
  visibility_timeout_seconds = var.sqs_visibility_timeout
  max_receive_count         = var.sqs_max_receive_count
  
  tags = local.common_tags
}

# Lambda Functions
module "lambdas" {
  source = "./modules/lambdas"
  
  project_name = var.project_name
  environment  = var.environment
  
  # DynamoDB table names and ARNs
  orders_table_name        = module.dynamodb.orders_table_name
  orders_table_arn         = module.dynamodb.orders_table_arn
  failed_orders_table_name = module.dynamodb.failed_orders_table_name
  failed_orders_table_arn  = module.dynamodb.failed_orders_table_arn
  
  # SQS queue URLs and ARNs
  order_queue_url = module.sqs.order_queue_url
  order_queue_arn = module.sqs.order_queue_arn
  order_dlq_url   = module.sqs.order_dlq_url
  order_dlq_arn   = module.sqs.order_dlq_arn
  
  # Lambda configuration
  lambda_timeout      = var.lambda_timeout
  lambda_memory_size  = var.lambda_memory_size
  max_receive_count   = var.sqs_max_receive_count
  
  # Step Function ARN (will be provided after creation)
  step_function_arn = ""
  
  tags = local.common_tags
  
  depends_on = [module.dynamodb, module.sqs]
}

# Step Functions
module "stepfunctions" {
  source = "./modules/stepfunctions"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Lambda ARNs
  validator_lambda_arn     = module.lambdas.validator_lambda_arn
  order_storage_lambda_arn = module.lambdas.order_storage_lambda_arn
  
  # SQS queue URL
  order_queue_url = module.sqs.order_queue_url
  
  tags = local.common_tags
  
  depends_on = [module.lambdas, module.sqs]
}

# API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Lambda integration
  api_handler_lambda_arn           = module.lambdas.api_handler_lambda_arn
  api_handler_lambda_function_name = module.lambdas.api_handler_function_name
  
  tags = local.common_tags
  
  depends_on = [module.lambdas]
}

# # Monitoring and Alerting
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Resources to monitor
  order_dlq_url                = module.sqs.order_dlq_url
  order_dlq_name              = module.sqs.order_dlq_name
  step_function_arn           = module.stepfunctions.state_machine_arn
  lambda_function_names       = module.lambdas.lambda_function_names
  api_gateway_id              = module.api_gateway.api_gateway_id
  api_gateway_stage_name      = module.api_gateway.api_gateway_stage_name
  
  # Notification settings
  notification_email = var.notification_email
  
  tags = local.common_tags
  
  depends_on = [module.sqs, module.stepfunctions, module.lambdas, module.api_gateway]
}

# # CI/CD Pipeline (optional)
module "cicd" {
  count  = var.deploy_cicd_pipeline ? 1 : 0
  source = "./cicd"
  
  project_name = var.project_name
  environment  = var.environment
  
  github_repo_url           = var.github_repo_url
  github_branch             = var.github_branch
  github_token_secret_name  = var.github_token_secret_name
  
  tags = local.common_tags
}
