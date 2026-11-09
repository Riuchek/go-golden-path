variable "name" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones for public subnets. LocalStack accepts any well-formed names."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
