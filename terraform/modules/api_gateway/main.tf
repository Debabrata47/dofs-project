# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Role for API Gateway to push logs to CloudWatch
resource "aws_iam_role" "apigateway_cloudwatch" {
  name = "${var.project_name}-apigateway-cloudwatch-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach the AWS managed policy to allow pushing logs to CloudWatch
resource "aws_iam_role_policy_attachment" "apigateway_cloudwatch_attach" {
  role       = aws_iam_role.apigateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway Account-level settings to use the above IAM Role
resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch.arn
}


# API Gateway
resource "aws_api_gateway_rest_api" "order_api" {
  name        = "${var.project_name}-order-api-${var.environment}"
  description = "Order Processing API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-order-api-${var.environment}"
    Type = "APIGateway"
  })
}

# API Gateway Resource for /order
resource "aws_api_gateway_resource" "order" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_rest_api.order_api.root_resource_id
  path_part   = "order"
}

# API Gateway Method - POST /order
resource "aws_api_gateway_method" "order_post" {
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  resource_id   = aws_api_gateway_resource.order.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.order_validator.id
  request_models = {
    "application/json" = aws_api_gateway_model.order_model.name
  }
}

# API Gateway Method - OPTIONS /order (for CORS)
resource "aws_api_gateway_method" "order_options" {
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  resource_id   = aws_api_gateway_resource.order.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Request Validator
resource "aws_api_gateway_request_validator" "order_validator" {
  name                        = "order-validator"
  rest_api_id                 = aws_api_gateway_rest_api.order_api.id
  validate_request_body       = true
  validate_request_parameters = false
}

# Request Model
resource "aws_api_gateway_model" "order_model" {
  rest_api_id  = aws_api_gateway_rest_api.order_api.id
  name         = "OrderModel"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Order Schema"
    type      = "object"
    required  = ["customer_id", "items", "total_amount"]
    properties = {
      customer_id = {
        type = "string"
      }
      items = {
        type = "array"
        minItems = 1
        items = {
          type = "object"
          required = ["product_id", "quantity", "price"]
          properties = {
            product_id = {
              type = "string"
            }
            quantity = {
              type = "number"
              minimum = 1
            }
            price = {
              type = "number"
              minimum = 0
            }
          }
        }
      }
      total_amount = {
        type = "number"
        minimum = 0
      }
    }
  })
}

# Lambda Integration for POST
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.api_handler_lambda_arn}/invocations"
}

# Mock Integration for OPTIONS (CORS)
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Method Response for POST
resource "aws_api_gateway_method_response" "order_post_200" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method
  status_code = "200"


  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_method_response" "order_post_400" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method
  status_code = "400"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_method_response" "order_post_500" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true

  }
}

# Method Response for OPTIONS
resource "aws_api_gateway_method_response" "order_options_200" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

# Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_options.http_method
  status_code = aws_api_gateway_method_response.order_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.api_handler_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.order_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "order_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_method.order_post,
    aws_api_gateway_method.order_options
  ]

  rest_api_id = aws_api_gateway_rest_api.order_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.order.id,
      aws_api_gateway_method.order_post.id,
      aws_api_gateway_method.order_options.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_integration.options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "order_api_stage" {
  deployment_id = aws_api_gateway_deployment.order_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error          = "$context.error.message"
      errorType      = "$context.error.messageString"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-order-api-stage-${var.environment}"
    Type = "APIGatewayStage"
  })
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.order_api.id}/${var.environment}"
  retention_in_days = 14
  tags              = var.tags
}

# CloudWatch Log Group for API Gateway Access Logs
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "/aws/apigateway/${var.project_name}-order-api-${var.environment}-access"
  retention_in_days = 14
  tags              = var.tags
}
