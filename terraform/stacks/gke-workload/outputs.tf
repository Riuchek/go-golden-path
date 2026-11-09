output "namespace" {
  value = module.workload.namespace
}

output "otel_endpoint" {
  value = module.workload.otel_endpoint
}

output "app_service_account" {
  value = module.workload.app_service_account
}

output "collector_service_account" {
  value = module.workload.collector_service_account
}

output "dashboard_id" {
  value = module.monitoring.dashboard_id
}
