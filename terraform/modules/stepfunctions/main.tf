# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for Step Functions
resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-step-function-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Step Functions
resource "aws_iam_policy" "step_function_policy" {
  name = "${var.project_name}-step-function-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.validator_lambda_arn,
          var.order_storage_lambda_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "step_function_policy_attachment" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}

# Step Function State Machine
resource "aws_sfn_state_machine" "order_processing" {
  name     = "${var.project_name}-order-processing-${var.environment}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "Order Processing State Machine"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          "FunctionName" = var.validator_lambda_arn
          "Payload.$"    = "$"
        }
        ResultPath = "$.validation_result"
        Next       = "CheckValidation"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "ValidationFailed"
            ResultPath  = "$.error"
          }
        ]
      }
      CheckValidation = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.validation_result.Payload.validation_status"
            StringEquals  = "FAILED"
            Next          = "ValidationFailed"
          }
        ]
        Default = "StoreOrder"
      }
      StoreOrder = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          "FunctionName" = var.order_storage_lambda_arn
          "Payload.$"    = "$.validation_result.Payload"
        }
        ResultPath = "$.storage_result"
        Next       = "SendToQueue"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "StorageFailed"
            ResultPath  = "$.error"
          }
        ]
      }
      SendToQueue = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          "QueueUrl"     = var.order_queue_url
          "MessageBody.$" = "$.storage_result.Payload"
        }
        Next = "ProcessingComplete"
        Retry = [
          {
            ErrorEquals     = ["SQS.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "QueueFailed"
            ResultPath  = "$.error"
          }
        ]
      }
      ProcessingComplete = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS"
          message = "Order processing completed successfully"
        }
        End = true
      }
      ValidationFailed = {
        Type = "Pass"
        Result = {
          status  = "VALIDATION_FAILED"
          message = "Order validation failed"
        }
        End = true
      }
      StorageFailed = {
        Type = "Pass"
        Result = {
          status  = "STORAGE_FAILED"
          message = "Order storage failed"
        }
        End = true
      }
      QueueFailed = {
        Type = "Pass"
        Result = {
          status  = "QUEUE_FAILED"
          message = "Failed to send order to queue"
        }
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_function_logs.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }


  tags = merge(var.tags, {
    Name = "${var.project_name}-order-processing-${var.environment}"
    Type = "StepFunction"
  })
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_function_logs" {
  name              = "/aws/stepfunctions/${var.project_name}-order-processing-${var.environment}"
  retention_in_days = 14
  tags              = var.tags
}
