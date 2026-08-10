```hcl
output "destination_bucket_name" {
  description = "Destination GCS bucket name."
  value       = google_storage_bucket.migration_destination.name
}

output "destination_bucket_url" {
  description = "GCS bucket URL."
  value       = google_storage_bucket.migration_destination.url
}
```
