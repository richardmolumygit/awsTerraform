output "load_balancer_controller_role_arn" {
  value = module.load_balancer_controller_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  value = module.external_dns_irsa.iam_role_arn
}
