terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "${var.environment}.terraform.tfstate"
    region = var.state_region
  }
}

data "aws_eks_cluster" "this" {
  name = "${var.environment}-eks-cluster"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", data.aws_eks_cluster.this.name,
        "--region", var.aws_region
      ]
    }
  }
}

module "controller" {
  source = "../../modules/awsLoadBalancerController"

  cluster_name          = data.aws_eks_cluster.this.name
  aws_region            = var.aws_region
  vpc_id                = data.aws_eks_cluster.this.vpc_config[0].vpc_id
  role_arn              = data.terraform_remote_state.cluster.outputs.load_balancer_controller_role_arn
  external_dns_role_arn = try(data.terraform_remote_state.cluster.outputs.external_dns_role_arn, "")
}