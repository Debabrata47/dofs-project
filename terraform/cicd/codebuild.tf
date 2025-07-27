# CodeBuild Project
resource "aws_codebuild_project" "terraform_build" {
  name          = "${var.project_name}-terraform-build-${var.environment}"
  description   = "Terraform plan and apply for ${var.project_name}"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    
    environment_variable {
      name  = "TF_VAR_environment"
      value = var.environment
    }
    
    environment_variable {
      name  = "TF_VAR_project_name"
      value = var.project_name
    }
    
    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = aws_s3_bucket.terraform_state.bucket
    }
    
    environment_variable {
      name  = "TF_STATE_LOCK_TABLE"
      value = aws_dynamodb_table.terraform_state_lock.name
    }
    
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_logs.name
      stream_name = "build"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-terraform-build-${var.environment}"
    Type = "CodeBuild"
  })
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_logs" {
  name              = "/aws/codebuild/${var.project_name}-terraform-build-${var.environment}"
  retention_in_days = 14
  tags              = var.tags
}
