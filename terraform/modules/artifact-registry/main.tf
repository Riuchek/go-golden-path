resource "google_artifact_registry_repository" "services" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Images promoted by the golden path."

  labels = {
    platform = "golden-path"
  }
}

resource "google_artifact_registry_repository_iam_member" "writers" {
  for_each = toset(var.writers)

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.services.repository_id
  role       = "roles/artifactregistry.writer"
  member     = each.value
}
