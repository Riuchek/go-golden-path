locals {
  collector_ksa = "otel-collector"
  otel_endpoint = "http://otel-collector.observability.svc.cluster.local:4318"
}

resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = substr("app-${var.name}", 0, 30)
  display_name = "${var.name} workload"
  description  = "Bound to the app Kubernetes SA. No project roles until the app calls a GCP API."
}

resource "google_service_account" "collector" {
  project      = var.project_id
  account_id   = substr("${var.name}-otel", 0, 30)
  display_name = "${var.name} collector"
  description  = "Writes OTLP to the Telemetry API. The app does not."
}

resource "google_project_iam_member" "collector" {
  for_each = toset([
    "roles/telemetry.writer",
    "roles/serviceusage.serviceUsageConsumer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.collector.email}"
}

resource "google_service_account_iam_member" "app" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.name}]"
}

resource "google_service_account_iam_member" "collector" {
  service_account_id = google_service_account.collector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[observability/${local.collector_ksa}]"
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
    labels = {
      platform = "golden-path"
    }
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = {
      platform = "golden-path"
    }
  }
}
