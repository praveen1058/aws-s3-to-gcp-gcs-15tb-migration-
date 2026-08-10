```hcl
data "aws_iam_policy_document" "migration_read" {

  statement {
    sid    = "ListSourceBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "arn:aws:s3:::${var.source_bucket_name}"
    ]
  }

  statement {
    sid    = "ReadSourceObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]

    resources = [
      "arn:aws:s3:::${var.source_bucket_name}/*"
    ]
  }
}

resource "aws_iam_user" "migration" {
  name = "${var.project_name}-migration"

  tags = {
    Purpose = "S3-to-GCS migration"
  }
}

resource "aws_iam_user_policy" "migration_read" {
  name   = "${var.project_name}-s3-read"
  user   = aws_iam_user.migration.name
  policy = data.aws_iam_policy_document.migration_read.json
}
```
