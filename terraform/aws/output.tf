```hcl
output "source_bucket_arn" {
  description = "ARN of the source S3 bucket."
  value       = "arn:aws:s3:::${var.source_bucket_name}"
}

output "migration_user_name" {
  description = "IAM identity used for migration."
  value       = aws_iam_user.migration.name
}
```
