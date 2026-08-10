```hcl
resource "google_storage_bucket" "migration_destination" {
  name     = var.destination_bucket_name
  location = var.gcp_region

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  public_access_prevention = "enforced"

  labels = {
    project     = var.project_name
    environment = var.environment
    purpose     = "s3-to-gcs-migration"
  }

  lifecycle_rule {
    condition {
      age = 365
    }

    action {
      type = "Delete"
    }
  }
}
```
