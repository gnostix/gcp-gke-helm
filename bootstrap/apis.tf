# APIs the CI identity plumbing needs. Bootstrap runs before the root stack,
# so it can't rely on the root's apis.tf.
locals {
  bootstrap_services = [
    "iam.googleapis.com",                  # pools, providers, service accounts
    "iamcredentials.googleapis.com",       # mint short-lived SA tokens (impersonation)
    "sts.googleapis.com",                  # exchange GitHub's OIDC token for a Google token
    "cloudresourcemanager.googleapis.com", # project IAM bindings
  ]
}

resource "google_project_service" "bootstrap" {
  for_each           = toset(local.bootstrap_services)
  service            = each.value
  disable_on_destroy = false
}
