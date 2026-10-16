module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  enable_nat_gateway = true
  single_nat_gateway = true # Keeps costs down for daily lifecycles
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37.2"

  cluster_name    = "${var.environment}-eks-cluster"
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    workers = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
    }
  }
}

module "load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.environment}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role_policy" "load_balancer_controller_certificate_management" {
  name = "${var.environment}-load-balancer-controller-certificates"
  role = module.load_balancer_controller_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:AddTagsToCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:ListTagsForCertificate"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["acm:RequestCertificate"]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["acm:DeleteCertificate"]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
        Condition = {
          "ForAllValues:StringLike" = {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" = ["*.app.sugarshacktreats.com"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
      }
    ]
  })
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-external-dns"

  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:external-dns"
      ]
    }
  }
}

resource "aws_iam_role_policy" "external_dns_app_hostname" {
  name = "${var.environment}-external-dns-app-hostname"
  role = module.external_dns_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
        Condition = {
          "ForAllValues:StringLike" = {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" = [
              "app.sugarshacktreats.com",
              "external-dns-app.sugarshacktreats.com"
            ]
            "route53:ChangeResourceRecordSetsActions"     = ["CREATE", "UPSERT"]
            "route53:ChangeResourceRecordSetsRecordTypes" = ["A", "AAAA", "TXT"]
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      }
    ]
  })
}