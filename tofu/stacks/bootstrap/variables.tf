variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket for OpenTofu state."
  type        = string
}

variable "github_repository" {
  description = "GitHub repo allowed to deploy via OIDC, owner/name."
  type        = string
  default     = "Riuchek/go-golden-path"
}

variable "create_github_oidc" {
  description = "Create the GitHub OIDC provider and deploy role. Set false if the account already has the provider."
  type        = bool
  default     = true
}
