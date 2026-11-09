resource "kubernetes_service_account" "app" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.app.email
    }
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = var.name
    }
  }

  spec {
    replicas = var.min_replicas

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        service_account_name            = kubernetes_service_account.app.metadata[0].name
        automount_service_account_token = false

        security_context {
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = var.name
          image             = var.image
          image_pull_policy = "Always"

          port {
            container_port = 8080
            name           = "http"
          }

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
            value = local.otel_endpoint
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
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }

          security_context {
            run_as_non_root            = true
            run_as_user                = 65532
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = 8080
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    type     = var.service_type
    selector = { app = var.name }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}
