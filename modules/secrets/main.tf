# The project NUMBER (not ID) is part of every Workload Identity principal.
# A data source READS existing information; it creates nothing.
data "google_project" "this" {
  project_id = var.project_id
}

# -----------------------------------------------------------------------------
# The secret: a named container with metadata. It holds no data itself.
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret" "demo" {
  project   = var.project_id
  secret_id = "${var.name}-demo-secret"

  # Store the data in ONE region (same as the cluster): data residency + the
  # GKE add-on requires the secret version to be in the cluster's region.
  # Replication can't be changed after creation - changing it means a new secret.
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    app = "demo"
  }
}

# -----------------------------------------------------------------------------
# A version: the actual bytes. Secrets are versioned and versions immutable;
# "rotating" = adding a new version. Apps can pin a version or use "latest".
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "demo" {
  secret = google_secret_manager_secret.demo.id

  # Write-only: sent to the API on create/update, never read back, never in state.
  secret_data_wo = var.secret_value
  # Terraform can't compare a value it never stores, so this number is how you
  # say "the value changed": bump it -> a new version is created.
  secret_data_wo_version = var.secret_version
}

# -----------------------------------------------------------------------------
# Access: Workload Identity "direct resource access".
# We grant the role straight to the KUBERNETES service account's identity -
# no Google service account, no keys, no annotations needed.
# Scoped to THIS secret only (not project-wide).
# -----------------------------------------------------------------------------
locals {
  ksa_principal = join("/", [
    "principal://iam.googleapis.com/projects/${data.google_project.this.number}",
    "locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog",
    "subject/ns/${var.k8s_namespace}/sa/${var.k8s_service_account}",
  ])
}

resource "google_secret_manager_secret_iam_member" "app_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.demo.secret_id
  role      = "roles/secretmanager.secretAccessor" # read payloads; can't list or modify
  member    = local.ksa_principal
}
