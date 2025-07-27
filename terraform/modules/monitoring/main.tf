# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-alerts-${var.environment}"
    Type = "SNS"
  })
}

# SNS Topic Subscription
# resource "aws_sns_topic_subscription" "email_alerts" {
#   topic_arn = "arn:aws:sns:ap-south-1:835701951685:dofs-alerts-dev"
#   protocol  = "email"
#   endpoint  = var.notification_email
# }

# CloudWatch Alarm for DLQ Message Count
resource "aws_cloudwatch_metric_alarm" "dlq_message_count" {
  alarm_name          = "${var.project_name}-dlq-message-count-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.dlq_alert_threshold
  alarm_description   = "This metric monitors DLQ message count"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = var.order_dlq_name
  }

  tags = var.tags
}

# CloudWatch Alarm for Step Function Failed Executions
resource "aws_cloudwatch_metric_alarm" "step_function_failures" {
  alarm_name          = "${var.project_name}-step-function-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Step Function execution failures"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    StateMachineArn = var.step_function_arn
  }

  tags = var.tags
}

# CloudWatch Alarm for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = length(var.lambda_function_names)

  alarm_name          = "${var.project_name}-lambda-errors-${var.lambda_function_names[count.index]}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Lambda function errors for ${var.lambda_function_names[count.index]}"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_names[count.index]
  }

  tags = var.tags
}

# CloudWatch Alarm for API Gateway 4XX Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "${var.project_name}-api-gateway-4xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName   = "${var.project_name}-order-api-${var.environment}"
    Stage     = var.api_gateway_stage_name
  }

  tags = var.tags
}

# CloudWatch Alarm for API Gateway 5XX Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.project_name}-api-gateway-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName   = "${var.project_name}-order-api-${var.environment}"
    Stage     = var.api_gateway_stage_name
  }

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main_dashboard" {
  dashboard_name = "${var.project_name}-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${var.project_name}-order-api-${var.environment}", "Stage", var.api_gateway_stage_name],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."],
            [".", "Latency", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "API Gateway Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = concat([
            for fn_name in var.lambda_function_names : [
              ["AWS/Lambda", "Invocations", "FunctionName", fn_name],
              [".", "Errors", ".", "."],
              [".", "Duration", ".", "."]
            ]
          ]...)
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Lambda Function Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", "StateMachineArn", var.step_function_arn],
            [".", "ExecutionsSucceeded", ".", "."],
            [".", "ExecutionsFailed", ".", "."],
            [".", "ExecutionTime", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Step Function Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", replace(var.order_dlq_name, "${var.project_name}-", "")],
            [".", "ApproximateNumberOfVisibleMessages", ".", "."],
            [".", "NumberOfMessagesReceived", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "SQS DLQ Metrics"
        }
      }
    ]
  })
}
