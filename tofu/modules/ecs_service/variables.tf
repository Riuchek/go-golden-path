variable "name" {
  description = "Service name. Also the OTEL service.name."
  type        = string
}

variable "image" {
  description = "App image reference, including tag."
  type        = string
}

variable "collector_image" {
  description = "OpenTelemetry Collector contrib image. Sidecar talks OTLP to the backend; the app never does."
  type        = string
  default     = "otel/opentelemetry-collector-contrib:0.165.0"
}

variable "collector_config" {
  description = "Collector YAML mounted into the sidecar."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "subnet_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  description = "Needed on LocalStack and on single-public-subnet demos. Prefer private subnets + NAT in production."
  type        = bool
  default     = true
}

variable "vpc_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
