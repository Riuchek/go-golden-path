variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

variable "github_repository" {
  type    = string
  default = "Riuchek/go-golden-path"
}

variable "repository_id" {
  type    = string
  default = "services"
}
