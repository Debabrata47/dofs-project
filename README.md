# DOFS (Distributed Order Fulfillment System):

A production-grade event-driven serverless architecture using AWS services and Terraform for automated order processing with CI/CD pipeline.

## Architecture Overview

```
API Gateway --> Lambda (API Handler)
                      |
                      v
              Step Function Orchestrator
                      |
     +----------------+----------------+
     |                |                |
     v                v                v
Validate Lambda --> Store Lambda --> SQS Queue --> Fulfillment Lambda
                     |                                      |
                     v                                      v
              DynamoDB (orders)                    DynamoDB update + DLQ
```

## Components

### 1. API Gateway
- REST endpoint for order submission
- POST /order with JSON validation
- CORS enabled for web clients

### 2. Lambda Functions
- **API Handler**: Receives orders and triggers Step Function
- **Validator**: Validates order data structure
- **Order Storage**: Saves validated orders to DynamoDB
- **Fulfillment**: Processes orders from SQS (70% success rate simulation)

### 3. Step Functions
- Orchestrates the order processing workflow
- Handles errors and retries
- Sends orders to SQS for asynchronous fulfillment

### 4. Data Storage
- **Orders Table**: Primary order storage with GSI for customer and status queries
- **Failed Orders Table**: Stores orders that failed fulfillment after max retries

### 5. Message Queue
- **Order Queue**: Main processing queue with configurable visibility timeout
- **Dead Letter Queue**: Captures failed messages after max receive count

### 6. Monitoring & Alerting
- CloudWatch dashboards and alarms
- SNS notifications for critical events
- DLQ depth monitoring

## Prerequisites

### Required Software
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Python 3.9+](https://www.python.org/downloads/) (for Lambda development)

### Required AWS Permissions
Your AWS user/role needs permissions for:
- IAM (roles, policies)
- Lambda (functions, layers)
- API Gateway (REST APIs, deployments)
- DynamoDB (tables, indexes)
- SQS (queues, policies)
- Step Functions (state machines)
- CloudWatch (logs, alarms, dashboards)
- SNS (topics, subscriptions)
- S3 (buckets for state and artifacts)
- CodePipeline and CodeBuild (if using CI/CD)
- Secrets Manager (for GitHub token)

## Quick Start

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd dofs-project
```

### 2. Configure Terraform Backend (Optional but Recommended)
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket --region ap-south-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --region ap-south-1

# Copy and configure backend
cp terraform/backend.conf.example terraform/backend.conf
# Edit backend.conf with your bucket name
```

### 3. Configure Variables
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 4. Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init -backend-config=backend.conf

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

### 5. Test the System
```bash
# Get API Gateway URL from Terraform output
API_URL=$(terraform output -raw api_gateway_url)

# Test order submission
curl -X POST $API_URL/order \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust_123",
    "items": [
      {
        "product_id": "prod_456",
        "quantity": 2,
        "price": 29.99
      }
    ],
    "total_amount": 59.98
  }'
```

## Configuration

### Core Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `ap-south-1` |
| `environment` | Environment name (dev/staging/prod) | `dev` |
| `project_name` | Project name prefix | `dofs` |
| `notification_email` | Email for alerts | Required |

### Performance Tuning
| Variable | Description | Default |
|----------|-------------|---------|
| `lambda_timeout` | Lambda function timeout (seconds) | `30` |
| `lambda_memory_size` | Lambda memory allocation (MB) | `256` |
| `sqs_visibility_timeout` | SQS message visibility timeout | `180` |
| `sqs_max_receive_count` | Max retries before DLQ | `3` |

### Monitoring
| Variable | Description | Default |
|----------|-------------|---------|
| `enable_dlq_alerting` | Enable DLQ depth alerts | `true` |
| `dlq_alert_threshold` | Messages in DLQ to trigger alert | `5` |

## CI/CD Pipeline

### Setup GitHub Actions (Recommended)
1. Set up repository secrets:
   ```
   AWS_ACCESS_KEY_ID
   AWS_SECRET_ACCESS_KEY
   ```

2. Set up repository variables:
   ```
   AWS_REGION=ap-south-1
   ENVIRONMENT=dev
   PROJECT_NAME=dofs
   NOTIFICATION_EMAIL=your-email@example.com
   TF_STATE_BUCKET=dofs-state-bucket
   TF_STATE_LOCK_TABLE=terraform-state-lock
   ```

3. Push to main branch to trigger deployment

### Setup AWS CodePipeline (Alternative)
1. Create CodeStart Connection and add the arn in terraform script

2. Deploy CI/CD infrastructure:
   ```bash
   # Update terraform.tfvars
   deploy_cicd_pipeline = true
   github_repo_url = "https://github.com/your-username/dofs-project" 
   # Apply changes
   terraform apply
   ```

## Testing Guide

### Success Scenario
1. Submit a valid order via API Gateway
2. Monitor Step Function execution in AWS Console
3. Check DynamoDB orders table for stored order
4. Verify order appears in SQS queue
5. Confirm fulfillment Lambda processes the order
6. Check final order status in DynamoDB

### Failure Scenario Testing
1. Submit an invalid order (missing required fields)
2. Verify validation failure in Step Function
3. Test SQS message failures by temporarily breaking fulfillment Lambda
4. Confirm failed messages move to DLQ after max retries
5. Verify failed orders appear in failed_orders table
6. Check CloudWatch alarms trigger

### Monitoring Verification
1. Access CloudWatch Dashboard (URL in Terraform output)
2. Verify metrics for API Gateway, Lambda, Step Functions, SQS
3. Test alert notifications by triggering DLQ threshold
4. Check SNS email notifications

## Troubleshooting

### Common Issues

#### Terraform Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform configuration
terraform validate

# Check for resource conflicts
terraform plan
```

#### Lambda Function Errors
```bash
# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/dofs

# View specific function logs
aws logs tail /aws/lambda/dofs-api-handler-dev --follow
```

#### Step Function Failures
1. Go to AWS Step Functions console
2. Click on your state machine
3. Review failed executions
4. Check execution input/output and error details

#### API Gateway Issues
```bash
# Test API Gateway directly
aws apigateway test-invoke-method \
  --rest-api-id YOUR_API_ID \
  --resource-id YOUR_RESOURCE_ID \
  --http-method POST \
  --path-with-query-string /order \
  --body '{"customer_id":"test","items":[{"product_id":"test","quantity":1,"price":10}],"total_amount":10}'
```

#### DynamoDB Access Issues
```bash
# Check table exists
aws dynamodb describe-table --table-name dofs-orders-dev

# Verify IAM permissions
aws iam get-role-policy --role-name dofs-lambda-execution-role-dev --policy-name dofs-lambda-policy-dev
```

### Performance Optimization

#### Lambda Cold Starts
- Increase memory allocation (faster CPU)
- Use provisioned concurrency for critical functions
- Optimize package size and dependencies

#### DynamoDB Performance
- Monitor consumed capacity units
- Adjust billing mode (On-Demand vs Provisioned)
- Add GSIs for common query patterns

#### SQS Optimization
- Tune visibility timeout based on processing time
- Use batch operations for higher throughput
- Implement exponential backoff for retries

## Security Considerations

### IAM Least Privilege
- Each Lambda has minimal required permissions
- Cross-service access is explicitly defined
- No wildcard permissions in production

### Data Protection
- DynamoDB encryption at rest enabled
- SQS messages encrypted in transit
- CloudWatch logs retention configured

### Network Security
- API Gateway with request validation
- CORS properly configured
- VPC endpoints for private communication (optional)

## Cost Optimization

### Serverless Benefits
- Pay-per-use pricing model
- Automatic scaling with demand
- No idle resource costs

### Cost Monitoring
- CloudWatch billing alarms recommended
- DynamoDB On-Demand for unpredictable traffic
- Lambda provisioned concurrency only when needed

### Resource Cleanup
```bash
# Destroy infrastructure when not needed
terraform destroy

# Clean up S3 buckets (manual)
aws s3 rb s3://your-terraform-state-bucket --force
```

## Development Guidelines

### Adding New Lambda Functions
1. Create function directory under `lambdas/`
2. Add ZIP file creation in `terraform/modules/lambdas/main.tf`
3. Update IAM policies as needed
4. Add to monitoring dashboard

### Modifying Step Function
1. Update definition in `terraform/modules/stepfunctions/main.tf`
2. Test changes with sample payloads
3. Update error handling as needed

### Database Schema Changes
1. Update table definitions in `terraform/modules/dynamodb/main.tf`
2. Plan migration strategy for existing data
3. Test with sample data

## Support

### Documentation
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

### Monitoring
- CloudWatch Dashboard: Available in Terraform output
- Log Groups: `/aws/lambda/dofs-*` and `/aws/stepfunctions/dofs-*`
- Metrics: Custom dashboard with key performance indicators

## License

This project is licensed under the MIT License - see the LICENSE file for details.
