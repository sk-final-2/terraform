# (선택) 오리진 보호용 비밀 헤더
resource "random_password" "edge_secret" {
  length  = 24
  special = false
}

resource "aws_cloudfront_distribution" "alb_https" {
  enabled             = true
  comment             = "RecruitAI via ALB"
  price_class         = "PriceClass_200"
  is_ipv6_enabled     = true
  http_version        = "http2"
  wait_for_deployment = true

  origin {
    origin_id   = "alb-origin"
    domain_name = aws_lb.this.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # ALB까지는 HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # 헤더 이름은 custom_header (origin_custom_header 아님)
    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.edge_secret.result
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    # 동적 트래픽: 캐시 0, 모든 헤더/쿠키/쿼리 포워드
    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies { forward = "all" }
    }

    # 전송량 절감
    compress = true

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # 도메인 없이 HTTPS
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}

# 편의용 출력 (도메인/시크릿 확인)
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.alb_https.domain_name
}
output "edge_secret" {
  value     = random_password.edge_secret.result
  sensitive = true
}
