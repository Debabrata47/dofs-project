#!/bin/bash

# DOFS Project Summary and Quick Setup
# This script provides an overview and quick setup for the DOFS system

echo "🚀 DOFS (Distributed Order Fulfillment System)"
echo "=============================================="
echo ""
echo "A production-grade event-driven serverless architecture for order processing"
echo "Built with AWS services and managed with Terraform"
echo ""

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "terraform" ]; then
    echo "❌ Please run this script from the dofs-project root directory"
    exit 1
fi

echo "📋 Project Structure:"
echo "   lambdas/           - Lambda function source code"
echo "   terraform/         - Infrastructure as Code"
echo "   terraform/modules/ - Reusable Terraform modules"
echo "   terraform/cicd/    - CI/CD pipeline infrastructure"
echo "   .github/workflows/ - GitHub Actions workflow"
echo ""

echo "🏗️  Architecture Components:"
echo "   ✅ API Gateway - REST endpoint for order submission"
echo "   ✅ Lambda Functions - API handler, validator, storage, fulfillment"
echo "   ✅ Step Functions - Order processing orchestration"
echo "   ✅ DynamoDB - Order storage and failed orders tracking"
echo "   ✅ SQS - Message queuing with dead letter queue"
echo "   ✅ CloudWatch - Monitoring, logging, and alerting"
echo "   ✅ SNS - Email notifications for critical events"
echo "   ✅ CI/CD Pipeline - Automated deployment with CodePipeline"
echo ""

echo "🛠️  Prerequisites Check:"

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform --version | head -n1 | awk '{print $2}')
    echo "   ✅ Terraform: $TERRAFORM_VERSION"
else
    echo "   ❌ Terraform not found - Please install Terraform >= 1.0"
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}')
    echo "   ✅ AWS CLI: $AWS_VERSION"
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        AWS_REGION=$(aws configure get region)
        echo "   ✅ AWS Credentials configured"
        echo "      Account: $AWS_ACCOUNT"
        echo "      Region: ${AWS_REGION:-us-east-1 (default)}"
    else
        echo "   ⚠️  AWS credentials not configured"
    fi
else
    echo "   ❌ AWS CLI not found - Please install AWS CLI v2"
fi

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    echo "   ✅ Python: $PYTHON_VERSION"
else
    echo "   ❌ Python 3 not found - Required for Lambda development"
fi

echo ""

# Check if already deployed
if [ -f "terraform/terraform.tfstate" ] || [ -f "terraform/.terraform/terraform.tfstate" ]; then
    echo "🔄 Existing Deployment Detected"
    echo "   Use the following commands to manage your deployment:"
    echo ""
    echo "   📊 Check system health:"
    echo "      ./monitor_system.sh"
    echo ""
    echo "   🧪 Test the system:"
    echo "      API_URL=\$(cd terraform && terraform output -raw api_gateway_url)"
    echo "      ./test_system.sh \$API_URL"
    echo ""
    echo "   🔍 View outputs:"
    echo "      cd terraform && terraform output"
    echo ""
    echo "   ♻️  Update deployment:"
    echo "      cd terraform && terraform apply"
    echo ""
    echo "   🗑️  Destroy deployment:"
    echo "      cd terraform && terraform destroy"
    echo ""
else
    echo "🚀 Quick Start Guide:"
    echo ""
    echo "1. Configure your deployment:"
    echo "   cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
    echo "   # Edit terraform.tfvars with your settings"
    echo ""
    echo "2. (Optional) Setup Terraform backend:"
    echo "   # Create S3 bucket and DynamoDB table for state management"
    echo "   cp terraform/backend.conf.example terraform/backend.conf"
    echo "   # Edit backend.conf with your bucket details"
    echo ""
    echo "3. Deploy the infrastructure:"
    echo "   cd terraform"
    echo "   terraform init"
    echo "   terraform plan"
    echo "   terraform apply"
    echo ""
    echo "4. Test your deployment:"
    echo "   API_URL=\$(terraform output -raw api_gateway_url)"
    echo "   cd .. && ./test_system.sh \$API_URL"
    echo ""
fi

echo "📚 Documentation:"
echo "   📖 README.md      - Complete project documentation"
echo "   🚀 DEPLOYMENT.md  - Detailed deployment guide"
echo "   🔗 GitHub Actions - Automated CI/CD pipeline"
echo ""

echo "💡 Key Features:"
echo "   🔄 Event-driven architecture with automatic scaling"
echo "   🛡️  Built-in error handling and dead letter queues"
echo "   📊 Comprehensive monitoring and alerting"
echo "   🧪 Automated testing and health checks"
echo "   💰 Cost-optimized serverless design"
echo "   🔒 Security best practices implemented"
echo ""

echo "📞 Getting Help:"
echo "   🐛 Issues: Check CloudWatch logs and run monitor_system.sh"
echo "   📋 Docs: README.md and DEPLOYMENT.md contain detailed guides"
echo "   🔧 Config: All settings in terraform/terraform.tfvars"
echo ""

echo "🎯 Next Steps:"
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "   1. Copy and configure terraform.tfvars"
    echo "   2. Run 'cd terraform && terraform init && terraform apply'"
    echo "   3. Test with ./test_system.sh"
else
    echo "   1. Review your terraform.tfvars configuration"
    echo "   2. Deploy with 'cd terraform && terraform apply'"
    echo "   3. Monitor with './monitor_system.sh'"
fi

echo ""
echo "Happy building! 🎉"
