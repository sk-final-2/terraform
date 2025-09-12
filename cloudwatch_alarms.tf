# CPU High
resource "aws_cloudwatch_metric_alarm" "ecs_backend_cpu_high" {
  alarm_name          = "${var.name}-backend-cpu-high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 2
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.backend.name
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}

# Memory High
resource "aws_cloudwatch_metric_alarm" "ecs_backend_mem_high" {
  alarm_name          = "${var.name}-backend-mem-high"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.backend.name
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "rds_free_space_low" {
  alarm_name          = "${var.name}-rds-free-space-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 50
  threshold           = 10 * 1024 * 1024 * 1024 # 10 GiB
  comparison_operator = "LessThanThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mariadb.id }
  alarm_actions       = [aws_sns_topic.ops.arn]
  treat_missing_data  = "notBreaching"
}

# Redis Evictions 발생
resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.name}-redis-evictions"
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}

# 1) ALB 자체 5xx (LB가 만든 5xx)
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}

# 2) Target 5xx (백엔드에서 터지는 5xx)
resource "aws_cloudwatch_metric_alarm" "tg_5xx" {
  alarm_name          = "${var.name}-tg-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.nginx.arn_suffix
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}

# (선택) 응답 지연 (TargetResponseTime 초 단위)
resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "${var.name}-alb-latency-high"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1.5 # 평균 1.5초 초과 시 알람 (원하면 조정)
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.nginx.arn_suffix
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}

# (선택) 비정상 타겟 증가 (AZ 중 최악값 잡으려면 Maximum 추천)
resource "aws_cloudwatch_metric_alarm" "tg_unhealthy" {
  alarm_name          = "${var.name}-tg-unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.nginx.arn_suffix
  }
  alarm_actions      = [aws_sns_topic.ops.arn]
  treat_missing_data = "notBreaching"
}
data "aws_instances" "cw_enabled" {
  filter {
    name   = "tag:cw:enabled"
    values = ["true"]
  }
  # 필요하면 상태 필터도 추가 가능
  # filter { name = "instance-state-name" values = ["running"] }
}

# CPU High (5분 평균 80%↑)
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  for_each            = toset(data.aws_instances.cw_enabled.ids)
  alarm_name          = "${var.name}-ec2-${each.value}-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = each.value }
  alarm_actions       = [aws_sns_topic.ops.arn]
  treat_missing_data  = "notBreaching"
}

# StatusCheck Failed (하드/네트워크 이상)
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  for_each            = toset(data.aws_instances.cw_enabled.ids)
  alarm_name          = "${var.name}-ec2-${each.value}-status-check-failed"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { InstanceId = each.value }
  alarm_actions       = [aws_sns_topic.ops.arn]
  treat_missing_data  = "notBreaching"
}