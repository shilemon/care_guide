# Remote state in S3 with state locking (use_lockfile needs Terraform >= 1.10).
# Create the bucket once (versioning on), then:
#   terraform init -backend-config="key=staging/terraform.tfstate"
# Without an AWS account use: terraform init -backend=false
terraform {
  backend "s3" {
    bucket       = "REPLACE-WITH-YOUR-STATE-BUCKET"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
