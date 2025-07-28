# Data source for AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Lambda functions
resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.orders_table_arn,
          "${var.orders_table_arn}/*",
          var.failed_orders_table_arn,
          "${var.failed_orders_table_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = [
          var.order_queue_arn,
          var.order_dlq_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:StopExecution",
          "states:ListStateMachines"
        ]
        Resource = var.step_function_arn != "" ? var.step_function_arn : "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Create ZIP files for Lambda functions
data "archive_file" "api_handler_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/api_handler"
  output_path = "${path.module}/api_handler.zip"
}

data "archive_file" "validator_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/validator"
  output_path = "${path.module}/validator.zip"
}

data "archive_file" "order_storage_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/order_storage"
  output_path = "${path.module}/order_storage.zip"
}

data "archive_file" "fulfill_order_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/fulfill_order"
  output_path = "${path.module}/fulfill_order.zip"
}

# API Handler Lambda
resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.api_handler_zip.output_path
  function_name    = "${var.project_name}-api-handler-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.api_handler_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT       = var.environment
      PROJECT_NAME      = var.project_name

    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-handler-${var.environment}"
    Type = "Lambda"
  })
}

# Validator Lambda
resource "aws_lambda_function" "validator" {
  filename         = data.archive_file.validator_zip.output_path
  function_name    = "${var.project_name}-validator-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.validator_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-validator-${var.environment}"
    Type = "Lambda"
  })
}

# Order Storage Lambda
resource "aws_lambda_function" "order_storage" {
  filename         = data.archive_file.order_storage_zip.output_path
  function_name    = "${var.project_name}-order-storage-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.order_storage_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      PROJECT_NAME        = var.project_name
      ORDERS_TABLE_NAME   = var.orders_table_name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-order-storage-${var.environment}"
    Type = "Lambda"
  })
}

# Fulfillment Lambda
resource "aws_lambda_function" "fulfill_order" {
  filename         = data.archive_file.fulfill_order_zip.output_path
  function_name    = "${var.project_name}-fulfill-order-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.fulfill_order_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT              = var.environment
      PROJECT_NAME             = var.project_name
      ORDERS_TABLE_NAME        = var.orders_table_name
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      MAX_RECEIVE_COUNT        = var.max_receive_count
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-fulfill-order-${var.environment}"
    Type = "Lambda"
  })
}

# Event Source Mapping for SQS to Fulfillment Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.order_queue_arn
  function_name    = aws_lambda_function.fulfill_order.arn
  batch_size       = 10
  maximum_batching_window_in_seconds = 5

  depends_on = [aws_lambda_function.fulfill_order]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_handler_logs" {
  name              = "/aws/lambda/${aws_lambda_function.api_handler.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "validator_logs" {
  name              = "/aws/lambda/${aws_lambda_function.validator.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "order_storage_logs" {
  name              = "/aws/lambda/${aws_lambda_function.order_storage.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "fulfill_order_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fulfill_order.function_name}"
  retention_in_days = 14
  tags              = var.tags
}
