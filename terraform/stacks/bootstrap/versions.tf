# Local backend on purpose. This stack creates the bucket the other
# stacks use, so it cannot store its own state there on the first apply.
# Keep this state somewhere you can find it. Losing it means importing.

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.30.0, < 7.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
