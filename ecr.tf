module "ecr" {
  source = "./modules/awsECR"

  repository_name = "${var.environment}-app"
}