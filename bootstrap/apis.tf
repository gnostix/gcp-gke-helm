# APIs the CI identity plumbing needs. Bootstrap runs before the root stack,
# so it can't rely on the root's apis.tf.
#
# serviceusage: on your laptop, API calls are billed ("quota project") to the
# project set in your ADC; in CI they're billed to the CI service account's own
# project. So the lab project itself must have Service Usage enabled, or CI
# can't even read which APIs are on. CI can't fix this itself (chicken-and-egg).
locals {
  bootstrap_services = [
    "iam.googleapis.com",                  # pools, providers, service accounts
    "iamcredentials.googleapis.com",       # mint short-lived SA tokens (impersonation)
    "sts.googleapis.com",                  # exchange GitHub's OIDC token for a Google token
    "cloudresourcemanager.googleapis.com", # project IAM bindings
    "serviceusage.googleapis.com",         # list/enable APIs - CI's calls are billed to THIS project
  ]
}

resource "google_project_service" "bootstrap" {
  for_each           = toset(local.bootstrap_services)
  service            = each.value
  disable_on_destroy = false
}
