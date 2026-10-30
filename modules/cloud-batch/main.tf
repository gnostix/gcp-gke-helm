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

# Pull-through cache of Docker Hub. Job VMs have no external IP, so they can't
# reach docker.io - they pull <region>-docker.pkg.dev/<p>/<repo>/library/<img>
# over Private Google Access. First pull fetches from Docker Hub and caches it.
resource "google_artifact_registry_repository" "dockerhub" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.name}-dockerhub"
  description   = "Docker Hub proxy for Cloud Batch jobs."
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "Docker Hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  # Cached images are deleted after 7 days (re-fetched on next use).
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-cached-after-7d"
    action = "DELETE"
    condition {
      older_than = "604800s"
    }
  }
}