terraform {
  required_version = ">= 1.9"

  # Child modules declare WHICH providers they need and a minimum version,
  # but don't pin tightly or configure them: the root module owns the
  # `provider "google" {}` block and the exact version (via the lock file).
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}
