module "services" {
  source     = "../../modules/project-services"
  project_id = var.project_id
  services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "serviceusage.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "container.googleapis.com",
    "secretmanager.googleapis.com",
    "telemetry.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
  ]
}

module "wif" {
  source            = "../../modules/github-wif"
  project_id        = var.project_id
  github_repository = var.github_repository

  depends_on = [module.services]
}

module "registry" {
  source        = "../../modules/artifact-registry"
  project_id    = var.project_id
  region        = var.region
  repository_id = var.repository_id
  writers       = ["serviceAccount:${module.wif.deployer_email}"]

  depends_on = [module.services]
}

resource "google_storage_bucket" "state" {
  project                     = var.project_id
  name                        = var.state_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    platform = "golden-path"
  }

  depends_on = [module.services]
}

resource "google_storage_bucket_iam_member" "deployer" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${module.wif.deployer_email}"
}
