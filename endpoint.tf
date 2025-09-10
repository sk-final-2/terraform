# endpoint.tf (최종)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  # 보통 private만 연결
  route_table_ids = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.name}-${var.env}-s3-endpoint"
  }
}
