# DOFS Deployment Guide

This guide provides step-by-step instructions for deploying the Distributed Order Fulfillment System (DOFS).

## Pre-Deployment Checklist

### 1. Prerequisites Verification
```bash
# Check Terraform version
terraform --version
# Required: >= 1.0

# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Python version
python3 --version
# Required: >= 3.9
```

### 2. AWS Permissions Setup
Ensure your AWS credentials have the following permissions:
- IAM: Full access (for creating roles and policies)
- Lambda: Full access
- API Gateway: Full access
- DynamoDB: Full access
- SQS: Full access
- Step Functions: Full access
- CloudWatch: Full access
- SNS: Full access
- S3: Full access (for state and artifacts)
- Secrets Manager: Read access (for CI/CD)
- CodePipeline/CodeBuild: Full access (if using CI/CD)

### 3. Environment Setup
```bash
# Clone repository
git clone <your-repo-url>
cd dofs-project

# Make scripts executable
chmod +x test_system.sh
chmod +x monitor_system.sh
```

## Deployment Options

### Option 1: Basic Deployment (Recommended for first-time)

#### Step 1: Configure Backend (Optional but Recommended)
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket-unique-name --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1

# Configure backend
cp terraform/backend.conf.example terraform/backend.conf
# Edit backend.conf with your bucket name
```

#### Step 2: Configure Variables
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
```hcl
aws_region         = "us-east-1"  # Your preferred region
environment        = "dev"
project_name       = "dofs"       # Or your preferred name
notification_email = "your-email@example.com"  # Required for alerts

# Keep CI/CD disabled for initial deployment
deploy_cicd_pipeline = false
```

#### Step 3: Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init -backend-config=backend.conf

# Review deployment plan
terraform plan

# Apply configuration
terraform apply
```

#### Step 4: Test Deployment
```bash
# Get API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)
echo "API Gateway URL: $API_URL"

# Run test script
cd ..
./test_system.sh $API_URL
```

### Option 2: Production Deployment with CI/CD

#### Step 1: Complete Basic Deployment First
Follow Option 1 steps to ensure the core system works.

#### Step 2: Setup GitHub Integration
```bash
# Store GitHub token in AWS Secrets Manager
aws secretsmanager create-secret \
    --name github-token \
    --secret-string '{"token":"your_github_personal_access_token"}' \
    --region us-east-1
```

#### Step 3: Enable CI/CD
Edit `terraform/terraform.tfvars`:
```hcl
deploy_cicd_pipeline     = true
github_repo_url          = "https://github.com/your-username/dofs-project"
github_branch            = "main"
github_token_secret_name = "github-token"
```

#### Step 4: Deploy CI/CD Pipeline
```bash
cd terraform
terraform apply
```

#### Step 5: Configure Repository
Push your code to GitHub and configure the following repository secrets:
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Repository variables:
```
AWS_REGION=us-east-1
ENVIRONMENT=dev
PROJECT_NAME=dofs
NOTIFICATION_EMAIL=your-email@example.com
TF_STATE_BUCKET=your-terraform-state-bucket
TF_STATE_LOCK_TABLE=terraform-state-lock
```

## Post-Deployment Configuration

### 1. Verify System Health
```bash
# Run monitoring script
./monitor_system.sh dev

# Check CloudWatch Dashboard
echo "Dashboard URL: $(cd terraform && terraform output -raw cloudwatch_dashboard_url)"
```

### 2. Configure Alerts
- Check your email for SNS subscription confirmation
- Confirm the subscription to receive alerts

### 3. Test End-to-End Flow
```bash
# Submit test orders
API_URL=$(cd terraform && terraform output -raw api_gateway_url)
./test_system.sh $API_URL

# Monitor processing in AWS Console:
# 1. Step Functions: Check execution history
# 2. DynamoDB: Verify order storage
# 3. SQS: Monitor queue depths
# 4. CloudWatch: Review metrics
```

## Environment-Specific Deployments

### Development Environment
```hcl
# terraform/terraform.tfvars
environment        = "dev"
lambda_memory_size = 256
dlq_alert_threshold = 10
```

### Staging Environment
```hcl
# terraform/terraform.tfvars
environment        = "staging"
lambda_memory_size = 512
dlq_alert_threshold = 5
```

### Production Environment
```hcl
# terraform/terraform.tfvars
environment        = "prod"
lambda_memory_size = 1024
lambda_timeout     = 60
dlq_alert_threshold = 1
enable_dlq_alerting = true
```

## Troubleshooting Deployment Issues

### Common Terraform Errors

#### Error: S3 bucket already exists
```bash
# Use a unique bucket name
aws_s3_bucket_name = "dofs-state-your-unique-suffix"
```

#### Error: DynamoDB table already exists
```bash
# Check if table exists in different region
aws dynamodb list-tables --region us-east-1
```

#### Error: IAM permissions denied
```bash
# Check your AWS credentials and permissions
aws sts get-caller-identity
aws iam get-user
```

### Lambda Deployment Issues

#### Error: Function code too large
```bash
# Lambda functions use Python with minimal dependencies
# Check lambda package sizes:
cd lambdas/api_handler && du -sh *
```

#### Error: Lambda timeout
```bash
# Increase timeout in terraform/terraform.tfvars
lambda_timeout = 60
```

### API Gateway Issues

#### Error: CORS issues
API Gateway is configured with CORS support. If you encounter issues:
```bash
# Test CORS directly
curl -X OPTIONS $API_URL/order \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST"
```

### Step Function Issues

#### Error: State machine execution failed
1. Go to AWS Step Functions console
2. Find your state machine: `dofs-order-processing-dev`
3. Review failed executions
4. Check input/output and error details

## Monitoring and Maintenance

### Daily Checks
```bash
# Run health monitoring
./monitor_system.sh dev

# Check for errors in logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/dofs-api-handler-dev \
  --start-time $(date -d 'yesterday' +%s)000 \
  --filter-pattern ERROR
```

### Weekly Maintenance
1. Review CloudWatch dashboard
2. Check DLQ for failed messages
3. Review and clean up old DynamoDB items (TTL handles this automatically)
4. Update Lambda dependencies if needed

### Monthly Tasks
1. Review and optimize Lambda memory allocation
2. Analyze cost reports
3. Update Terraform and provider versions
4. Security review and updates

## Scaling Considerations

### High Traffic Scenarios
```hcl
# Increase Lambda concurrency
lambda_memory_size = 1024

# Enable DynamoDB auto-scaling or use On-Demand
# SQS scales automatically

# Consider API Gateway caching
```

### Multi-Region Deployment
For disaster recovery:
1. Deploy to secondary region
2. Use Route 53 for failover
3. Replicate DynamoDB data with Global Tables
4. Set up cross-region monitoring

## Security Hardening

### Production Security Checklist
- [ ] Enable AWS CloudTrail
- [ ] Configure VPC endpoints for private communication
- [ ] Use AWS Secrets Manager for sensitive data
- [ ] Enable AWS Config for compliance monitoring
- [ ] Set up AWS GuardDuty for threat detection
- [ ] Configure AWS WAF for API Gateway protection

### Network Security
```hcl
# Add VPC configuration for Lambda functions
vpc_config {
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]
}
```

## Backup and Recovery

### Backup Strategy
1. **DynamoDB**: Point-in-time recovery enabled by default
2. **Terraform State**: Versioned in S3
3. **Lambda Code**: Stored in Git repository
4. **Configuration**: Infrastructure as Code

### Recovery Procedures
```bash
# Restore from Terraform state
terraform import aws_dynamodb_table.orders table-name

# Redeploy Lambda functions
terraform apply -target=module.lambdas

# Restore DynamoDB from point-in-time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name original-table \
  --target-table-name restored-table \
  --restore-date-time 2023-01-01T12:00:00
```

## Cost Optimization

### Cost Monitoring
```bash
# Enable AWS Cost Explorer
# Set up billing alerts
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json
```

### Optimization Tips
1. Use DynamoDB On-Demand for variable workloads
2. Right-size Lambda memory allocation
3. Enable S3 lifecycle policies for logs
4. Use CloudWatch log retention policies
5. Monitor and adjust SQS visibility timeouts

## Support and Documentation

### AWS Console Links
- CloudWatch Dashboard: Available in Terraform output
- Step Functions: https://console.aws.amazon.com/states/
- Lambda Functions: https://console.aws.amazon.com/lambda/
- DynamoDB: https://console.aws.amazon.com/dynamodb/
- API Gateway: https://console.aws.amazon.com/apigateway/

### Useful Commands
```bash
# Get all Terraform outputs
cd terraform && terraform output

# Monitor Step Function executions
aws stepfunctions list-executions \
  --state-machine-arn $(cd terraform && terraform output -raw step_function_arn)

# Check SQS queue depths
aws sqs get-queue-attributes \
  --queue-url $(cd terraform && terraform output -raw order_queue_url) \
  --attribute-names All
```

This deployment guide should help you successfully deploy and maintain the DOFS system in any environment.
