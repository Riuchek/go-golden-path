variable "name" {
  description = "ECR repository name."
  type        = string
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "force_delete" {
  description = "Allow destroy even when the repo still has images. Useful for LocalStack sandboxes."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
