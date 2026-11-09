module "services" {
  source     = "../../modules/project-services"
  project_id = var.project_id
  services = [
    "container.googleapis.com",
    "telemetry.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "logging.googleapis.com",
  ]
}

module "workload" {
  source     = "../../modules/gke-workload"
  project_id = var.project_id
  region     = var.region
  name       = var.name
  namespace  = var.namespace
  image      = var.image

  collector_config = file("${path.module}/../../../otel/collector.gcp.yaml")
  service_type     = var.service_type

  depends_on = [module.services]
}

module "monitoring" {
  source       = "../../modules/monitoring"
  project_id   = var.project_id
  region       = var.region
  service_name = var.name
  namespace    = var.namespace
  platform     = "gke"

  depends_on = [module.services]
}
