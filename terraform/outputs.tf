# output "api_gateway_url" {
#   description = "API Gateway URL"
#   value       = module.api_gateway.api_gateway_url
# }

# output "api_gateway_id" {
#   description = "API Gateway ID"
#   value       = module.api_gateway.api_gateway_id
# }

# output "step_function_arn" {
#   description = "Step Function ARN"
#   value       = module.stepfunctions.state_machine_arn
# }

# output "step_function_name" {
#   description = "Step Function name"
#   value       = module.stepfunctions.state_machine_name
# }

# output "orders_table_name" {
#   description = "Orders DynamoDB table name"
#   value       = module.dynamodb.orders_table_name
# }

# output "failed_orders_table_name" {
#   description = "Failed orders DynamoDB table name"
#   value       = module.dynamodb.failed_orders_table_name
# }

# output "order_queue_url" {
#   description = "Order SQS queue URL"
#   value       = module.sqs.order_queue_url
# }

# output "order_dlq_url" {
#   description = "Order DLQ URL"
#   value       = module.sqs.order_dlq_url
# }

# output "lambda_function_names" {
#   description = "Lambda function names"
#   value       = module.lambdas.lambda_function_names
# }

# output "sns_topic_arn" {
#   description = "SNS topic ARN for notifications"
#   value       = module.monitoring.sns_topic_arn
# }

# output "cloudwatch_dashboard_url" {
#   description = "CloudWatch dashboard URL"
#   value       = module.monitoring.dashboard_url
# }

# # CI/CD Pipeline outputs
# output "codepipeline_name" {
#   description = "CodePipeline name"
#   value       = try(module.cicd[0].pipeline_name, "Not deployed")
# }

# output "codebuild_project_name" {
#   description = "CodeBuild project name"
#   value       = try(module.cicd[0].codebuild_project_name, "Not deployed")
# }

# output "terraform_state_bucket" {
#   description = "S3 bucket for Terraform state"
#   value       = try(module.cicd[0].terraform_state_bucket, "Not configured")
# }
