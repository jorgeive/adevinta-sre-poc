resource "aws_route53_zone" "cluster" {
  name = local.kubernetes_cluster_name
}

resource "aws_route53_zone" "postgres" {
  name = "postgresl.adevinta-test.com"
}

