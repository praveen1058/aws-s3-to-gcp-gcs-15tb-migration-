```hcl
variable "gcp_project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for regional resources."
  type        = string
}

variable "destination_bucket_name" {
  description = "Destination Google Cloud Storage bucket."
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
