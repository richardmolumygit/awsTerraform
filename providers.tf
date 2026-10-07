terraform {
    required_version = ">= 1.5.0"
    required_providers {
        aws = {
            source = "hashicopr/aws"
            version = "~> 5.0"
        }
    }
}

# Minimalist, single-user remote state backend configuration
backend "s3" {
    bucket = ""
}