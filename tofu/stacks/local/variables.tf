variable "region" {
  type    = string
  default = "us-east-1"
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL. From the host use http://localhost:4566; from another compose service use http://localstack:4566."
  type        = string
  default     = "http://localhost:4566"
}

variable "name" {
  type    = string
  default = "checkout"
}

variable "image" {
  description = "App image. Against LocalStack this is usually the locally built Chainguard image tag."
  type        = string
  default     = "checkout:local"
}

variable "state_bucket_name" {
  description = "Demo S3 bucket created inside LocalStack."
  type        = string
  default     = "golden-path-tfstate"
}
