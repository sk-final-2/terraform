# ALB SG – public HTTP
resource "aws_security_group" "alb" {
  name   = "${var.name}-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# App SG – nginx (ALB에서만 인바운드 허용은 아래 alb_to_nginx 규칙으로 부여)
resource "aws_security_group" "app" {
  name   = "${var.name}-app-sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Backend/Services SG
# - nginx(App SG) -> Front 3000, Backend 8080 허용
# - Backend(svc) -> AI(svc) 8000/8001/8003 내부 통신 허용 (외부 미노출)
resource "aws_security_group" "svc" {
  name   = "${var.name}-svc-sg"
  vpc_id = module.vpc.vpc_id

  # nginx(App SG) -> Front(3000)
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # nginx(App SG) -> Backend(8080)
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Backend(svc) -> AI(svc) 내부 통신
  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 8001
    to_port   = 8001
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 8003
    to_port   = 8003
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB SG – only from backend SG
resource "aws_security_group" "db" {
  name   = "${var.name}-db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.svc.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Redis SG – only from backend SG
resource "aws_security_group" "redis" {
  name   = "${var.name}-redis-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.svc.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow ALB -> nginx only
resource "aws_security_group_rule" "alb_to_nginx" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}
