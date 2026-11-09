variable "project_id" {
  type = string
}

variable "github_repository" {
  description = "GitHub repo allowed to deploy, in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "Use owner/name, for example Riuchek/go-golden-path."
  }
}

variable "restrict_to_main_branch" {
  description = "When true, only ref refs/heads/main can impersonate the deployer."
  type        = bool
  default     = true
}
