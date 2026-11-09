locals {
  # A config change must roll a new revision. Cloud Run reads the secret
  # when the revision is created, not on a later secret update.
  config_rev = substr(sha256(var.collector_config), 0, 12)
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = substr("${var.name}-run", 0, 28)
  display_name = "${var.name} Cloud Run runtime"
  description  = "Identity shared by the app container and the collector sidecar."
}

# The collector, not the app, writes traces and metrics. Cloud Run has one
# identity per revision, so these roles sit on the runtime account.
resource "google_project_iam_member" "telemetry" {
  for_each = toset([
    "roles/telemetry.writer",
    "roles/serviceusage.serviceUsageConsumer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret" "collector" {
  project   = var.project_id
  secret_id = "${var.name}-otel-collector"

  replication {
    auto {}
  }

  labels = {
    platform = "golden-path"
  }
}

resource "google_secret_manager_secret_version" "collector" {
  secret      = google_secret_manager_secret.collector.id
  secret_data = var.collector_config
}

resource "google_secret_manager_secret_iam_member" "collector" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.collector.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_cloud_run_v2_service" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.region
  ingress             = var.ingress
  deletion_protection = var.deletion_protection

  labels = {
    platform = "golden-path"
    service  = var.name
  }

  template {
    service_account                  = google_service_account.runtime.email
    timeout                          = "30s"
    max_instance_request_concurrency = 80

    labels = {
      platform = "golden-path"
      service  = var.name
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    volumes {
      name = "collector-config"
      secret {
        secret       = google_secret_manager_secret.collector.secret_id
        default_mode = 292 # 0444
        items {
          version = google_secret_manager_secret_version.collector.version
          path    = "config.yaml"
        }
      }
    }

    containers {
      name  = "app"
      image = var.image

      ports {
        container_port = 8080
      }

      depends_on = ["collector"]

      env {
        name  = "PORT"
        value = "8080"
      }
      env {
        name  = "OTEL_SERVICE_NAME"
        value = var.name
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4318"
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = "http/protobuf"
      }
      env {
        name  = "OTEL_TRACES_EXPORTER"
        value = "otlp"
      }
      env {
        name  = "OTEL_METRICS_EXPORTER"
        value = "otlp"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # Explicit because setting resources changes the Cloud Run default.
        # The app can idle; the sidecar below cannot.
        cpu_idle          = true
        startup_cpu_boost = true
      }

      startup_probe {
        http_get {
          path = "/readyz"
          port = 8080
        }
        period_seconds    = 5
        timeout_seconds   = 3
        failure_threshold = 12
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds = 15
      }
    }

    containers {
      name  = "collector"
      image = var.collector_image
      args  = ["--config=/etc/otelcol-google/config.yaml"]

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "OTEL_CONFIG_REV"
        value = local.config_rev
      }

      volume_mounts {
        name       = "collector-config"
        mount_path = "/etc/otelcol-google"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # cpu_idle = true throttles the sidecar between requests and the
        # collector drops the batch it was about to export.
        cpu_idle          = false
        startup_cpu_boost = true
      }

      startup_probe {
        http_get {
          path = "/"
          port = 13133
        }
        period_seconds    = 5
        timeout_seconds   = 3
        failure_threshold = 12
      }

      liveness_probe {
        http_get {
          path = "/"
          port = 13133
        }
        period_seconds = 15
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.collector,
    google_project_iam_member.telemetry,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.public_invoker ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
