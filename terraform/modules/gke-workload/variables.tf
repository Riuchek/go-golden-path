variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  description = "Workload name. Used for the Deployment, Service, and OTEL service.name."
  type        = string
  default     = "checkout"
}

variable "namespace" {
  type    = string
  default = "checkout"
}

variable "image" {
  description = "App image, including the tag."
  type        = string
}

variable "collector_image" {
  description = "Google-built collector. Keep this aligned with otel/collector.gcp.yaml."
  type        = string
  default     = "us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:0.164.0"
}

variable "collector_config" {
  description = "Collector YAML mounted from a ConfigMap."
  type        = string
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 5
}

variable "service_type" {
  description = "ClusterIP keeps the service inside the cluster. LoadBalancer allocates an external address and is the expensive way to poke at a demo."
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "LoadBalancer"], var.service_type)
    error_message = "service_type must be ClusterIP or LoadBalancer."
  }
}
