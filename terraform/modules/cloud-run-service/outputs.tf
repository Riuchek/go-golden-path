output "uri" {
  description = "HTTPS URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.this.uri
}

output "name" {
  value = google_cloud_run_v2_service.this.name
}

output "service_account" {
  value = google_service_account.runtime.email
}

output "location" {
  value = google_cloud_run_v2_service.this.location
}
