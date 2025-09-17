# Helper: container log options
locals {
  # 공통
  log_opts = {
    awslogs-group         = aws_cloudwatch_log_group.lg.name
    awslogs-region        = var.region
    awslogs-stream-prefix = "ecs"
    awslogs-create-group  = "true" # ← 없으면 생성 실패할 수 있어 추가
  }

  # Spring Boot(백엔드) 스택트레이스 줄바꿈 묶기
  log_opts_java = merge(local.log_opts, {
    "awslogs-multiline-pattern" = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"
  })
}

# ===== Service Discovery services =====
resource "aws_service_discovery_service" "sd_front" {
  name = "front-nextjs"
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ns.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_service_discovery_service" "sd_backend" {
  name = "spring-backend"
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ns.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_service_discovery_service" "sd_emotion" {
  name = "emotion-ai"
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ns.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_service_discovery_service" "sd_interv" {
  name = "interview-ai"
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ns.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_service_discovery_service" "sd_track" {
  name = "tracking-ai"
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ns.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

# ===== Task Definitions =====
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.name}-nginx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu_mem.nginx.cpu
  memory                   = var.task_cpu_mem.nginx.mem
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name             = "nginx"
      image            = var.image_nginx
      essential        = true
      portMappings     = [{ containerPort = 80, hostPort = 80 }]
      logConfiguration = { logDriver = "awslogs", options = local.log_opts }
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q --spider http://127.0.0.1:80/healthz || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

resource "aws_ecs_task_definition" "front" {
  family                   = "${var.name}-front"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu_mem.front.cpu
  memory                   = var.task_cpu_mem.front.mem
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name             = "front"
      image            = var.image_front
      essential        = true
      portMappings     = [{ containerPort = 3000, hostPort = 3000 }]
      logConfiguration = { logDriver = "awslogs", options = local.log_opts }
      environment = [
        { name = "NEXT_PUBLIC_API_URL", value = "/api" }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu_mem.backend.cpu
  memory                   = var.task_cpu_mem.backend.mem
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name             = "backend"
      image            = var.image_backend
      essential        = true
      portMappings     = [{ containerPort = 8080, hostPort = 8080 }]
      logConfiguration = { logDriver = "awslogs", options = local.log_opts_java }
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:mariadb://${aws_db_instance.mariadb.address}:3306/recruit?useUnicode=true&characterEncoding=utf8&connectionCollation=utf8mb4_unicode_ci" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password },
        { name = "SPRING_DATA_REDIS_HOST", value = aws_elasticache_replication_group.redis.primary_endpoint_address },
        { name = "SPRING_DATA_REDIS_PORT", value = "6379" },
        { name = "GOOGLE_CLIENT_ID", value = var.google_client_id },
        { name = "GOOGLE_CLIENT_SECRET", value = var.google_client_secret },
        { name = "KAKAO_CLIENT_ID", value = var.kakao_client_id },
        { name = "JWT_SECRET", value = var.jwt_secret },
        { name = "MAIL_USERNAME", value = var.mail_username },
        { name = "MAIL_PASSWORD", value = var.mail_password },
        { name = "NAVER_MAIL_USERNAME", value = var.naver_mail_username },
        { name = "NAVER_MAIL_PASSWORD", value = var.naver_mail_password },
        { name = "FRONTEND_URL", value = var.frontend_external_url },
        { name = "EMOTION_SERVER_URL", value = "http://emotion-ai.${var.sd_namespace}:8000/analyze" },
        { name = "STT_SERVER_URL", value = "http://interview-ai.${var.sd_namespace}:8001/stt-ask" },
        { name = "FIRST_ASK_SERVER_URL", value = "http://interview-ai.${var.sd_namespace}:8001" },
        { name = "TRACKING_SERVER_URL", value = "http://tracking-ai.${var.sd_namespace}:8003/tracking" },
        { name = "EVALUATE_SERVER_URL", value = "http://evaluate-ai.${var.sd_namespace}:8002/evaluate" },
        { name = "AWS_S3_BUCKET", value = aws_s3_bucket.media.bucket },
        { name = "S3_BUCKET", value = aws_s3_bucket.media.bucket },
        { name = "AWS_REGION", value = var.region }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/actuator/health || wget -q --spider http://127.0.0.1:8080/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

resource "aws_ecs_task_definition" "emotion" {
  family                   = "${var.name}-emotion"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu_mem.emotion.cpu
  memory                   = var.task_cpu_mem.emotion.mem
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name             = "emotion"
      image            = var.image_emotion
      essential        = true
      portMappings     = [{ containerPort = 8000, hostPort = 8000 }]
      logConfiguration = { logDriver = "awslogs", options = local.log_opts }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c 'import urllib.request,sys; sys.exit(0 if urllib.request.urlopen(\"http://127.0.0.1:8000/healthz\", timeout=2).status==200 else 1)' || python3 -c 'import urllib.request,sys; sys.exit(0 if urllib.request.urlopen(\"http://127.0.0.1:8000/healthz\", timeout=2).status==200 else 1)' || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 240
      }
    }
  ])
}

resource "aws_ecs_task_definition" "interview" {
  family                   = "${var.name}-interview"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu_mem.interview.cpu
  memory                   = var.task_cpu_mem.interview.mem
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  ephemeral_storage {
    size_in_gib = 50
  }

  container_definitions = jsonencode([
    {
      name             = "interview"
      image            = var.image_interview
      essential        = true
      portMappings     = [{ containerPort = 8001, hostPort = 8001 }]
      logConfiguration = { logDriver = "awslogs", options = local.log_opts }
      environment = [
        { name = "OPENAI_API_KEY", value = var.openai_api_key }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c 'import urllib.request,sys; sys.exit(0 if urllib.request.urlopen(\"http://127.0.0.1:8001/healthz\", timeout=2).status==200 else 1)' || python3 -c 'import urllib.request,sys; sys.exit(0 if urllib.request.urlopen(\"http://127.0.0.1:8001/healthz\", timeout=2).status==200 else 1)' || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 240
      }

    }
  ])
}

resource "aws_ecs_task_definition" "tracking" {
  family                   = "${var.name}-tracking"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu_mem.tracking.cpu
  memory                   = var.task_cpu_mem.tracking.mem
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name             = "tracking"
      image            = var.image_tracking
      essential        = true
      portMappings     = [{ containerPort = 8003, hostPort = 8003 }]
      logConfiguration = { logDriver = "awslogs", options = local.log_opts }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c 'import urllib.request,sys; sys.exit(0 if urllib.request.urlopen(\"http://127.0.0.1:8003/healthz\", timeout=2).status==200 else 1)' || python3 -c 'import urllib.request,sys; sys.exit(0 if urllib.request.urlopen(\"http://127.0.0.1:8003/healthz\", timeout=2).status==200 else 1)' || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 240
      }
    }
  ])
}

# ===== ECS Services =====
resource "aws_ecs_service" "nginx" {
  name            = "${var.name}-nginx"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = var.desired_nginx
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx.arn
    container_name   = "nginx"
    container_port   = 80
  }
}

resource "aws_ecs_service" "front" {
  name            = "${var.name}-front"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.front.arn
  desired_count   = var.desired_front
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sd_front.arn
  }
}

resource "aws_ecs_service" "backend" {
  name            = "${var.name}-backend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_backend
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sd_backend.arn
  }
}

resource "aws_ecs_service" "emotion" {
  name            = "${var.name}-emotion"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.emotion.arn
  desired_count   = var.desired_emotion
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sd_emotion.arn
  }
}

resource "aws_ecs_service" "interview" {
  name            = "${var.name}-interview"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.interview.arn
  desired_count   = var.desired_interview
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sd_interv.arn
  }
}

resource "aws_ecs_service" "tracking" {
  name            = "${var.name}-tracking"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.tracking.arn
  desired_count   = var.desired_tracking
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sd_track.arn
  }
}
