resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  enable_autopilot    = true
  deletion_protection = var.deletion_protection

  # Workload Identity is always on for Autopilot. Setting
  # workload_identity_config here is rejected by the API.

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {}

  resource_labels = {
    platform = "golden-path"
  }
}
