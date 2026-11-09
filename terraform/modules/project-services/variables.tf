variable "project_id" {
  description = "GCP project that will host the golden path."
  type        = string
}

variable "services" {
  description = "APIs to enable. Disabling them on destroy is intentionally off."
  type        = set(string)
}
