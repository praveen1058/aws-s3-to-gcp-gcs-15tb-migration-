```hcl
variable "aws_region" {
  description = "AWS region containing the source S3 bucket."
  type        = string
}

variable "source_bucket_name" {
  description = "Existing AWS S3 bucket containing the migration data."
  type        = string
}

variable "project_name" {
  description = "Project identifier."
  type        = string
  default     = "s3-to-gcs-migration"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "production"
}
```
