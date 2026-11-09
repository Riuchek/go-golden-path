variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "checkout"
}

variable "image" {
  description = "Full image reference in ECR, including tag."
  type        = string
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "create_registry" {
  description = "Create the ECR repository in this stack. Set false when a shared registry already exists."
  type        = bool
  default     = true
}
