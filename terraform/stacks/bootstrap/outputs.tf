output "github_actions_variables" {
  description = "Copy these into GitHub Actions variables. None of them are secrets."
  value = {
    GCP_PROJECT_ID                 = var.project_id
    GCP_REGION                     = var.region
    GCP_WORKLOAD_IDENTITY_PROVIDER = module.wif.provider_name
    GCP_DEPLOYER_SERVICE_ACCOUNT   = module.wif.deployer_email
    TF_STATE_BUCKET                = google_storage_bucket.state.name
    GCP_GKE_CLUSTER                = "golden-path"
  }
}

output "image_prefix" {
  value = module.registry.image_prefix
}
