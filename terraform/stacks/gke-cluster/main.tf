data "google_project" "this" {
  project_id = var.project_id
}

module "services" {
  source     = "../../modules/project-services"
  project_id = var.project_id
  services = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

module "cluster" {
  source              = "../../modules/gke-autopilot"
  project_id          = var.project_id
  region              = var.region
  name                = var.cluster_name
  deletion_protection = var.deletion_protection

  depends_on = [module.services]
}

# Autopilot pulls images as the default Compute Engine service account.
resource "google_artifact_registry_repository_iam_member" "nodes" {
  project    = var.project_id
  location   = var.region
  repository = var.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_project.this.number}-compute@developer.gserviceaccount.com"

  depends_on = [module.cluster]
}
