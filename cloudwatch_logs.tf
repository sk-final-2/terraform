resource "aws_cloudwatch_log_group" "backend" {
  name              = "/recruitai/backend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/recruitai/frontend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "ai_deepface" {
  name              = "/recruitai/ai/deepface"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "ai_mediapipe" {
  name              = "/recruitai/ai/mediapipe"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/recruitai/redis/slow"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = "/recruitai/redis/engine"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/recruitai/vpc/flow"
  retention_in_days = 7
}
