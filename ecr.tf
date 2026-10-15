module "ecr" {
  source = "./modules/awsECR"

  repository_name = "springwebpage"
}