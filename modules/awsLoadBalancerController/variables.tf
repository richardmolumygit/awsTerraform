variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "chart_version" {
  type    = string
  default = "1.13.0"
}