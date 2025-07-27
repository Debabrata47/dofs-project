output "api_handler_lambda_arn" {
  description = "ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.arn
}

output "api_handler_function_name" {
  description = "Name of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "api_handler_invoke_arn" {
  description = "Invoke ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.invoke_arn
}

output "validator_lambda_arn" {
  description = "ARN of the validator Lambda function"
  value       = aws_lambda_function.validator.arn
}

output "order_storage_lambda_arn" {
  description = "ARN of the order storage Lambda function"
  value       = aws_lambda_function.order_storage.arn
}

output "fulfill_order_lambda_arn" {
  description = "ARN of the fulfill order Lambda function"
  value       = aws_lambda_function.fulfill_order.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_function_names" {
  description = "List of all Lambda function names"
  value = [
    aws_lambda_function.api_handler.function_name,
    aws_lambda_function.validator.function_name,
    aws_lambda_function.order_storage.function_name,
    aws_lambda_function.fulfill_order.function_name
  ]
}

output "api_handler_environment_vars" {
  description = "Environment variables for API handler Lambda"
  value = {
    ENVIRONMENT  = var.environment
    PROJECT_NAME = var.project_name
  }
}
