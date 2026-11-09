variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "namespace" {
  description = "Kubernetes namespace for the GKE dashboard filter."
  type        = string
  default     = "checkout"
}

variable "platform" {
  description = "Which dashboard and alerts to create."
  type        = string

  validation {
    condition     = contains(["cloud_run", "gke"], var.platform)
    error_message = "platform must be cloud_run or gke."
  }
}

variable "notification_email" {
  description = "Optional email for alert policies. Empty keeps the policies visible in the console without paging anyone."
  type        = string
  default     = ""
}
