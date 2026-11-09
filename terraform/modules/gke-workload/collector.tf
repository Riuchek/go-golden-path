resource "kubernetes_service_account" "collector" {
  metadata {
    name      = local.collector_ksa
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.collector.email
    }
  }
}

resource "kubernetes_config_map" "collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  data = {
    "config.yaml" = var.collector_config
  }
}

resource "kubernetes_deployment" "collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      app = "otel-collector"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "otel-collector"
      }
    }

    template {
      metadata {
        labels = {
          app = "otel-collector"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.collector.metadata[0].name

        security_context {
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "collector"
          image             = var.collector_image
          image_pull_policy = "IfNotPresent"
          args              = ["--config=/etc/otelcol-google/config.yaml"]

          env {
            name  = "GOOGLE_CLOUD_PROJECT"
            value = var.project_id
          }

          port {
            container_port = 4317
            name           = "otlp-grpc"
          }
          port {
            container_port = 4318
            name           = "otlp-http"
          }
          port {
            container_port = 13133
            name           = "health"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/otelcol-google"
            read_only  = true
          }

          startup_probe {
            http_get {
              path = "/"
              port = 13133
            }
            period_seconds    = 5
            failure_threshold = 12
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 13133
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.collector.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  spec {
    selector = { app = "otel-collector" }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }
    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
    }
  }
}
