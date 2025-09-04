locals {
  ecr_repos = [
    "nginx-gateway",
    "frontend",
    "backend",
    "emotion-ai",
    "interview-ai",
    "tracking-ai",
  ]
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(local.ecr_repos)
  name                 = "recruitai/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  # 돈 아끼려면 false 유지(켜면 Inspector 과금)
  image_scanning_configuration { scan_on_push = false }
}

resource "aws_ecr_lifecycle_policy" "keep_last_10" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last 10 images",
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
      action       = { type = "expire" }
    }]
  })
}

# 앱 스택이 참조할 수 있게 URL 출력
output "ecr_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
