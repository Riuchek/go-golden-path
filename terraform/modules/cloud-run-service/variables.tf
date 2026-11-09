variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  description = "Cloud Run service name. Also the OTEL service.name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,47}[a-z0-9]$", var.name)) || can(regex("^[a-z]$", var.name))
    error_message = "Use a Cloud Run service name: lowercase letters, digits, and hyphens."
  }
}

variable "image" {
  description = "App image, including the tag. CI sets this to the commit SHA."
  type        = string
}

variable "collector_image" {
  description = "Google-built collector. Keep this aligned with otel/collector.gcp.yaml."
  type        = string
  default     = "us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:0.164.0"
}

variable "collector_config" {
  description = "Collector YAML stored in Secret Manager and mounted into the sidecar."
  type        = string
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 5
}

variable "public_invoker" {
  description = "Grant roles/run.invoker to allUsers. Leave false until you mean the service to be reachable without identity."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "ingress" {
  type    = string
  default = "INGRESS_TRAFFIC_ALL"
}
