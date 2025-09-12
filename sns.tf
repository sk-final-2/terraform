variable "alarm_email" { default = "ajtwlstpgns@naver.com" }

resource "aws_sns_topic" "ops" {
  name = "${var.name}-ops"
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.ops.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}