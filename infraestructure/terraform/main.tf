provider "aws" {
  region = "eu-west-3"
}

terraform {
  backend "s3" {
    bucket = "tf-state-adevinta"
    key    = "prod/terraform"
    region = "eu-west-3"
  }
}

locals {
  azs                    = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  environment            = "prod"
  kops_state_bucket_name = "local.environment-kops-state"
  kubernetes_cluster_name = "k8s.adevinta-test.com"
  ingress_ips             = "0.0.0.0/0"
  vpc_name                = "local.environment-vpc"

  tags = {
    environment = local.environment
    terraform   = true
  }
}

data "aws_region" "current" {}