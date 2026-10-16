resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      vpcId       = var.vpc_id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.role_arn
        }
      }

      controllerConfig = {
        featureGates = {
          EnableCertificateManagement = true
        }
      }
    })
  ]
}

resource "helm_release" "external_dns" {
  count      = var.external_dns_role_arn == "" ? 0 : 1
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.23.0"
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
        }
      }

      sources          = ["ingress"]
      provider         = { name = "aws" }
      policy           = "upsert-only"
      registry         = "txt"
      txtOwnerId       = var.cluster_name
      txtPrefix        = "external-dns-"
      domainFilters    = ["sugarshacktreats.com"]
      annotationFilter = "external-dns.kubernetes.io/hostname=app.sugarshacktreats.com"
      extraArgs        = { "aws-zone-type" = "public" }
      env = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
    })
  ]
}