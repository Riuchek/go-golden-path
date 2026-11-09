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

variable "name" {
  type    = string
  default = "checkout"
}

variable "namespace" {
  type    = string
  default = "checkout"
}

variable "image" {
  description = "Full image reference, including tag."
  type        = string
}

variable "service_type" {
  type    = string
  default = "ClusterIP"
}
