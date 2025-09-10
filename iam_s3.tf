# iam_s3.tf

# 2-1) 객체 권한 (tmp/, media/만)
data "aws_iam_policy_document" "s3_media_objects" {
  statement {
    sid = "AllowObjectOpsOnMediaPrefixes"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload"
    ]
    resources = [
      "${aws_s3_bucket.media.arn}/tmp/*",
      "${aws_s3_bucket.media.arn}/media/*",
    ]
  }
}

resource "aws_iam_policy" "s3_media_objects" {
  name   = "${var.name}-${var.env}-s3-media-objects"
  policy = data.aws_iam_policy_document.s3_media_objects.json
}

# 2-2) 버킷 권한 (ListBucket)
data "aws_iam_policy_document" "s3_media_bucket" {
  statement {
    sid       = "AllowListBucketMedia"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.media.arn]
    # 원하면 접두어 제한:
    # condition {
    #   test     = "StringLike"
    #   variable = "s3:prefix"
    #   values   = ["tmp/*", "media/*"]
    # }
  }
}

resource "aws_iam_policy" "s3_media_bucket" {
  name   = "${var.name}-${var.env}-s3-media-bucket"
  policy = data.aws_iam_policy_document.s3_media_bucket.json
}

# 2-3) 우리가 만든 Task Role에 직접 부착 (변수 없이!)
resource "aws_iam_role_policy_attachment" "attach_s3_objects_to_task" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.s3_media_objects.arn
}

resource "aws_iam_role_policy_attachment" "attach_s3_bucket_to_task" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.s3_media_bucket.arn
}
