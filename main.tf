# This is where the CI/CD pipeline runs execution commands.
# It sources the dynamic S3 backend, 
# and calls the local module using a relative directory path.
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Backend is still partial; CI/CD will inject the S3 details dynamically
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# Call your newly created custom module
module "cluster_env" {
  source = "./modules/awsEKS"

  environment = var.environment
  aws_region  = var.aws_region

  # Optional overrides can go here if passed from root variables
  node_instance_types = var.instance_types
}