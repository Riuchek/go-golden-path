output "dashboard_id" {
  description = "Cloud Monitoring dashboard id, when this platform has one."
  value = try(
    google_monitoring_dashboard.cloud_run[0].id,
    google_monitoring_dashboard.gke[0].id,
    null,
  )
}
