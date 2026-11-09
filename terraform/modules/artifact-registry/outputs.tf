output "repository_id" {
  value = google_artifact_registry_repository.services.repository_id
}

output "image_prefix" {
  description = "Push images under this prefix, then a name and a tag."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.services.repository_id}"
}
