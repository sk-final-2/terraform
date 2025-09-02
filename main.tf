resource "aws_vpc" "smoke" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "tf-smoke" }
}

output "vpc_id" { value = aws_vpc.smoke.id }
