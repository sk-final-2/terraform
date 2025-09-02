provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "ap-northeast-2" # 서울
}
