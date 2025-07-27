resource "aws_sqs_queue" "order_dlq" {
  name = "${var.project_name}-order-dlq-${var.environment}"

  message_retention_seconds = 1209600 # 14 days
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-order-dlq-${var.environment}"
    Type = "SQS-DLQ"
  })
}

resource "aws_sqs_queue" "order_queue" {
  name                      = "${var.project_name}-order-queue-${var.environment}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 20 # Long polling
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-order-queue-${var.environment}"
    Type = "SQS"
  })
}

# SQS Queue Policy for Lambda access
resource "aws_sqs_queue_policy" "order_queue_policy" {
  queue_url = aws_sqs_queue.order_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.order_queue.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# SQS Queue Policy for DLQ
resource "aws_sqs_queue_policy" "order_dlq_policy" {
  queue_url = aws_sqs_queue.order_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSQSAccess"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.order_dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sqs_queue.order_queue.arn
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
