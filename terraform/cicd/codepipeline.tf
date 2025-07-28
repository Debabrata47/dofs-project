# Get GitHub token from Secrets Manager
data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

# CodePipeline
resource "aws_codepipeline" "terraform_pipeline" {
  name     = "${var.project_name}-terraform-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "debabrata47/dofs-project"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "TerraformPlan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
        EnvironmentVariables = jsonencode([
          {
            name  = "TF_COMMAND"
            value = "plan"
          }
        ])
      }
    }
  }

  stage {
    name = "Approve"

    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Please review the Terraform plan and approve if changes look correct."
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "TerraformApply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["apply_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
        EnvironmentVariables = jsonencode([
          {
            name  = "TF_COMMAND"
            value = "apply"
          }
        ])
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-terraform-pipeline-${var.environment}"
    Type = "CodePipeline"
  })
}
