# -----------------------------------------------------------------------------
# Keyless Seqera Cloud -> GCP via Workload Identity Federation.
#   1. Seqera signs a short-lived OIDC token for a run/credential check.
#   2. Google STS validates it against the provider below (issuer + condition).
#   3. The identity impersonates gke-lab-seqera (binding lives in the root
#      stack: module.nextflow_batch, resource seqera_wif).
#
# Own pool, not the GitHub one: the SA binding is "pool/*", which must not
# include GitHub workflow identities.
# Values for the mapping/condition are the ones Seqera shows in its form.
# -----------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "seqera" {
  workload_identity_pool_id = "seqera" # deleted pool IDs are reserved for 30 days
  display_name              = "Seqera Platform"
  description               = "OIDC identities from Seqera Cloud (cloud.seqera.io)"

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "seqera" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.seqera.workload_identity_pool_id
  workload_identity_pool_provider_id = "seqera-cloud"
  display_name                       = "Seqera Cloud"

  oidc {
    issuer_uri = "https://cloud.seqera.io/api"
    # allowed_audiences not set -> defaults to this provider's resource name,
    # which is what Seqera sends when "Token audience" is left empty.
  }

  attribute_mapping = {
    # Tenant subject + acting Seqera user -> visible in Cloud Audit Logs.
    "google.subject" = "assertion.sub + (has(assertion.principal_id) ? ':usr:' + assertion.principal_id : '')"
  }

  # Hard gate: every Seqera Cloud customer shares this issuer. Only tokens
  # minted for OUR org + workspace get through.
  attribute_condition = "assertion.sub.startsWith('org:${var.seqera_org_id}:wsp:${var.seqera_workspace_id}:')"
}