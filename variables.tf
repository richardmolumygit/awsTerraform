# Root variables
variable "environment" { type = string }
variable "aws_region"  { type = string; default = "us-east-1" }
variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}