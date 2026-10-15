provider "google" {
  project = var.project_id
  region  = var.region

  # Applied to every resource that supports labels -> easy cost tracking / cleanup.
  default_labels = local.labels
}
