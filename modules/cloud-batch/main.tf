# -----------------------------------------------------------------------------
# Cloud Batch platform. Terraform owns what is long-lived (identity, data,
# permissions). Jobs themselves are submitted by users (batch-jobs/*.json) -
# they are one-off API objects and never live in Terraform state.
# -----------------------------------------------------------------------------

# Identity of every job VM. Never the Compute default SA (Editor on the project).
resource "google_service_account" "runner" {
  project      = var.project_id
  account_id   = "${var.name}-batch"
  display_name = "Cloud Batch job runner (${var.name})"
}

# Inputs/outputs for jobs. Jobs mount it at a path (gcsVolume) or use gcloud.
resource "google_storage_bucket" "data" {
  project  = var.project_id
  name     = "${var.project_id}-${var.name}-batch-data" # bucket names are global
  location = var.region                                 # same region as the VMs: no egress cost

  uniform_bucket_level_access = true       # IAM only, no per-object ACLs
  public_access_prevention    = "enforced" # can never be made public
  force_destroy               = var.force_destroy

  # Default soft-delete keeps deleted objects (billed) for 3 days. Not needed here.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  lifecycle_rule {
    condition {
      age = var.data_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
