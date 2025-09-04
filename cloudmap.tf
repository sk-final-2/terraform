resource "aws_service_discovery_private_dns_namespace" "ns" {
  name = var.sd_namespace
  vpc  = module.vpc.vpc_id
}
