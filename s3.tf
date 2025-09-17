resource "aws_s3_bucket" "media" {
  bucket        = "${var.name}-${var.env}-media"
  force_destroy = false
  tags          = { Project = var.name, Env = var.env }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

# tmp/는 7일 후 자동 삭제 (원하면 기간 조절)
resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    id     = "tmp-expire"
    status = "Enabled"
    filter { prefix = "tmp/" }
    expiration { days = 7 }
  }
}
