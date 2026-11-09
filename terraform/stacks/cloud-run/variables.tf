variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "name" {
  type    = string
  default = "checkout"
}

variable "image" {
  description = "Full image reference, including tag."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repo created by the bootstrap stack."
  type        = string
  default     = "services"
}

variable "public_invoker" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "notification_email" {
  type    = string
  default = ""
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 5
}
