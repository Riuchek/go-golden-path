variable "project_id" {
  type = string
}

variable "region" {
  description = "Autopilot is regional. This is the cluster location."
  type        = string
}

variable "name" {
  type    = string
  default = "golden-path"
}

variable "deletion_protection" {
  description = "Keep true outside a sandbox. Terraform will refuse to delete the cluster until this is false."
  type        = bool
  default     = true
}
