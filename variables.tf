variable "domain_main" { default = "recruitai.kr" } # 호스티드 존
variable "domain_app" { default = "app.recruitai.kr" }

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "name" {
  type    = string
  default = "recruitai"
}

# Private DNS namespace for ECS Service Discovery
variable "sd_namespace" {
  type    = string
  default = "recruitai.local"
}
variable "env" {
  type    = string
  default = "prod" # dev/stage/prod 중 택1
}

# Images (use the tags you already push to Docker Hub)
variable "image_nginx" {
  type    = string
  default = "804540872991.dkr.ecr.ap-northeast-2.amazonaws.com/recruitai/nginx-gateway:latest"
}
variable "image_front" {
  type    = string
  default = "804540872991.dkr.ecr.ap-northeast-2.amazonaws.com/recruitai/frontend:latest"
}
variable "image_backend" {
  type    = string
  default = "804540872991.dkr.ecr.ap-northeast-2.amazonaws.com/recruitai/backend:latest"
}
variable "image_emotion" {
  type    = string
  default = "804540872991.dkr.ecr.ap-northeast-2.amazonaws.com/recruitai/emotion-ai:latest"
}
variable "image_interview" {
  type    = string
  default = "804540872991.dkr.ecr.ap-northeast-2.amazonaws.com/recruitai/interview-ai:latest"
}
variable "image_tracking" {
  type    = string
  default = "804540872991.dkr.ecr.ap-northeast-2.amazonaws.com/recruitai/tracking-ai:latest"
}

# Desired counts (min setup for testing)
variable "desired_front" {
  type    = number
  default = 1
}
variable "desired_nginx" {
  type    = number
  default = 1
}
variable "desired_backend" {
  type    = number
  default = 2
}
variable "desired_emotion" {
  type    = number
  default = 1
}
variable "desired_interview" {
  type    = number
  default = 1
}
variable "desired_tracking" {
  type    = number
  default = 1
}

# CPU/Memory (Fargate requires specific pairs)
variable "task_cpu_mem" {
  type = object({
    nginx     = object({ cpu = string, mem = string })
    front     = object({ cpu = string, mem = string })
    backend   = object({ cpu = string, mem = string })
    emotion   = object({ cpu = string, mem = string })
    interview = object({ cpu = string, mem = string })
    tracking  = object({ cpu = string, mem = string })
  })
  default = {
    nginx     = { cpu = "512", mem = "2048" }
    front     = { cpu = "512", mem = "2048" }
    backend   = { cpu = "2048", mem = "4096" }
    emotion   = { cpu = "2048", mem = "4096" }
    interview = { cpu = "4096", mem = "12288" }
    tracking  = { cpu = "2048", mem = "4096" }
  }
}

# Spring/DB/Redis credentials & app secrets (pass via TF_VAR_* or tfvars)
variable "db_username" { type = string }
variable "db_password" { type = string }

variable "google_client_id" { type = string }
variable "google_client_secret" { type = string }
variable "kakao_client_id" { type = string }
variable "jwt_secret" { type = string }
variable "mail_username" { type = string }
variable "mail_password" { type = string }
variable "naver_mail_username" { type = string }
variable "naver_mail_password" { type = string }

variable "openai_api_key" { type = string } # for interview-ai

# Frontend URL (external)
variable "frontend_external_url" {
  type    = string
  default = ""
}

# Log retention
variable "log_retention_days" {
  type    = number
  default = 7
}
