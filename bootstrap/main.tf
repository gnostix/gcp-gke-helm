# Remote-state bucket for the main stack.
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate" # bucket names are global -> prefix with project id
  location = var.region

  uniform_bucket_level_access = true       # IAM only, no per-object ACLs
  public_access_prevention    = "enforced" # state can contain secrets: never public

  versioning {
    enabled = true # lets you recover a corrupted/overwritten state file
  }

  # Keep only the last 10 non-current versions of each state object.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Protects the bucket from an accidental `terraform destroy`.
  force_destroy = false
}
