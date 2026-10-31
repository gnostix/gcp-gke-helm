output "state_bucket" {
  description = "Put this value in ../backend.hcl"
  value       = google_storage_bucket.tfstate.name
}

# ---- paste these into GitHub -> Settings -> Secrets and variables -> Variables
output "github_variables" {
  description = "Repository VARIABLES for the workflow (not secrets - none of these grant access on their own)."
  value = {
    GCP_PROJECT_ID   = var.project_id
    TF_STATE_BUCKET  = google_storage_bucket.tfstate.name
    GCP_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    GCP_CI_SA        = google_service_account.ci.email
    CHART_REGISTRY   = local.chart_registry
  }
}

output "chart_registry" {
  description = "OCI base URL for Helm charts: helm push <chart>.tgz <this>"
  value       = "oci://${local.chart_registry}"
}

output "seqera_wif" {
  description = "Seqera credential form: 'Workload identity provider' = provider."
  value = {
    pool_name = google_iam_workload_identity_pool.seqera.name
    provider  = google_iam_workload_identity_pool_provider.seqera.name
  }
}