output "namespace" {
  value = kubernetes_namespace.app.metadata[0].name
}

output "service_name" {
  value = kubernetes_service.app.metadata[0].name
}

output "app_service_account" {
  description = "GCP service account bound to the app. It has no project roles."
  value       = google_service_account.app.email
}

output "collector_service_account" {
  value = google_service_account.collector.email
}

output "otel_endpoint" {
  value = local.otel_endpoint
}
