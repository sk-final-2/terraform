########################################
# CloudWatch Agent 설정(JSON) - SSM 파라미터
########################################
resource "aws_ssm_parameter" "cwagent_config" {
  name = "/recruitai/cloudwatch-agent-config"
  type = "String"
  value = jsonencode({
    agent = { metrics_collection_interval = 60 }
    metrics = {
      namespace = "RecruitAI/EC2"
      # Terraform 템플릿 이스케이프 필요: "$${...}"
      append_dimensions      = { InstanceId = "$${!aws:InstanceId}" }
      aggregation_dimensions = [["InstanceId"]]
      metrics_collected = {
        cpu  = { measurement = ["usage_system", "usage_user", "usage_idle"] }
        mem  = { measurement = ["mem_used_percent"] }
        disk = { resources = ["*"], measurement = ["used_percent"] }
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            # Ubuntu 계열
            { file_path = "/var/log/syslog", log_group_name = "/recruitai/ec2/syslog", log_stream_name = "{instance_id}", timestamp_format = "%b %d %H:%M:%S" },
            { file_path = "/var/log/auth.log", log_group_name = "/recruitai/ec2/auth", log_stream_name = "{instance_id}", timestamp_format = "%b %d %H:%M:%S" }
            # Amazon Linux 사용 시 /var/log/messages 로 바꾸세요.
          ]
        }
      }
    }
  })
}

########################################
# CloudWatch Agent 설치 (태그 기반)
########################################
resource "aws_ssm_association" "install_cwagent" {
  name = "AWS-ConfigureAWSPackage"
  targets {
    key    = "tag:cw:enabled"
    values = ["true"]
  }
  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }
}

########################################
# CloudWatch Agent 설정 적용 + 시작 (태그 기반)
########################################
resource "aws_ssm_association" "run_cwagent" {
  name = "AmazonCloudWatch-ManageAgent"
  targets {
    key    = "tag:cw:enabled"
    values = ["true"]
  }
  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationLocation = aws_ssm_parameter.cwagent_config.name
    optionalRestart               = "yes"
  }
}
