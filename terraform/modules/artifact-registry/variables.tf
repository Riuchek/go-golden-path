variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "repository_id" {
  type    = string
  default = "services"
}

variable "writers" {
  description = "Members granted artifactregistry.writer, usually the CI deployer."
  type        = list(string)
  default     = []
}
