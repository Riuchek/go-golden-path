variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "cluster_name" {
  type    = string
  default = "golden-path"
}

variable "repository_id" {
  type    = string
  default = "services"
}

variable "deletion_protection" {
  type    = bool
  default = true
}
