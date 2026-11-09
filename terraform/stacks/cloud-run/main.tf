data "google_project" "this" {
  project_id = var.project_id
}

module "services" {
  source     = "../../modules/project-services"
  project_id = var.project_id
  services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "telemetry.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "logging.googleapis.com",
  ]
}

# Cloud Run pulls through its service agent, not the runtime service account.
resource "google_artifact_registry_repository_iam_member" "cloud_run_agent" {
  project    = var.project_id
  location   = var.region
  repository = var.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${data.google_project.this.number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [module.services]
}

module "service" {
  source     = "../../modules/cloud-run-service"
  project_id = var.project_id
  region     = var.region
  name       = var.name
  image      = var.image

  collector_config    = file("${path.module}/../../../otel/collector.gcp.yaml")
  min_instances       = var.min_instances
  max_instances       = var.max_instances
  public_invoker      = var.public_invoker
  deletion_protection = var.deletion_protection

  depends_on = [module.services]
}

module "monitoring" {
  source             = "../../modules/monitoring"
  project_id         = var.project_id
  region             = var.region
  service_name       = var.name
  platform           = "cloud_run"
  notification_email = var.notification_email

  depends_on = [module.services]
}
