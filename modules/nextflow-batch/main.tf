# -----------------------------------------------------------------------------
# Nextflow on Cloud Batch, launched from Seqera Platform.
#   seqera  = credential SA: what Seqera acts as (via WIF) to launch the head job
#   nf-head = head job SA:   runs Nextflow AND every task VM
# -----------------------------------------------------------------------------
resource "google_service_account" "seqera" {
  project      = var.project_id
  account_id   = "${var.name}-seqera"
  display_name = "Seqera Platform credential (${var.name})"
}

resource "google_service_account" "head" {
  project      = var.project_id
  account_id   = "${var.name}-nf-head"
  display_name = "Nextflow head job + tasks on Cloud Batch (${var.name})"
}

# Two buckets with the same shape -> one block, for_each over a map of objects.
locals {
  buckets = {
    work = {
      suffix = "nf-work" # Nextflow workDir: big, temporary
      days   = var.work_retention_days
    }
    results = {
      suffix = "nf-out" # --outdir: what users keep
      days   = var.results_retention_days
    }
  }
}

resource "google_storage_bucket" "this" {
  for_each = local.buckets

  project  = var.project_id
  name     = "${var.project_id}-${var.name}-${each.value.suffix}"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  lifecycle_rule {
    condition {
      age = each.value.days
    }
    action {
      type = "Delete"
    }
  }
}
