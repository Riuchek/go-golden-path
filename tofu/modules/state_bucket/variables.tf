variable "name" {
  description = "Globally unique S3 bucket name for OpenTofu state."
  type        = string
}

variable "force_destroy" {
  description = "Allow destroy with objects still present. Keep false outside LocalStack."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
