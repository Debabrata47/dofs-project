terraform {
  backend "s3" {
    # These values should be provided via backend config file or CLI
    # Example: terraform init -backend-config=backend.conf
    bucket         = "dofs-state-bucket"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
