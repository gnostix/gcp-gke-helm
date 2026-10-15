terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
  # No backend block: bootstrap keeps LOCAL state on purpose.
  # It creates the bucket that every other stack uses for remote state
  # (chicken-and-egg: the bucket can't store its own creation state).
}

provider "google" {
  project = var.project_id
  region  = var.region
}
