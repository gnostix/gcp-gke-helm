# -----------------------------------------------------------------------------
# Keyless CI: GitHub Actions -> GCP via Workload Identity Federation (WIF)
#
#   1. GitHub issues the job a short-lived OIDC token (JWT) that says
#      "repo=owner/name, ref=refs/heads/main, ..." - signed by GitHub.
#   2. Google STS validates it against the provider below and exchanges it
#      for a federated Google token.
#   3. That identity impersonates the CI service account (1h token).
# No JSON key ever exists, so there's nothing to leak or rotate.
#
# Lives in bootstrap because CI can't create the identity it logs in with.
# -----------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC identities from GitHub Actions"

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Copy claims from GitHub's token into Google attributes we can match on.
  attribute_mapping = {
    "google.subject"       = "assertion.sub" # e.g. repo:owner/name:ref:refs/heads/main
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }

  # Hard gate: tokens from ANY other repo are rejected at the door.
  # (Every GitHub repo in the world can mint tokens for this issuer.)
  attribute_condition = "assertion.repository == \"${var.github_repo}\""
}

# -----------------------------------------------------------------------------
# The service account CI acts as
# -----------------------------------------------------------------------------
resource "google_service_account" "ci" {
  account_id   = "github-terraform"
  display_name = "Terraform via GitHub Actions"

  depends_on = [google_project_service.bootstrap]
}

# Let identities from our repo (and only it) impersonate the CI SA.
resource "google_service_account_iam_member" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# Least-privilege-ish roles for what the root stack manages (steps 1-5).
# For a real environment: split plan (read-only) and apply SAs, and constrain
# projectIamAdmin with IAM Conditions - it can grant itself anything.
locals {
  ci_roles = [
    "roles/serviceusage.serviceUsageAdmin",  # step 1: enable APIs
    "roles/compute.networkAdmin",            # step 2: VPC, subnet, router, NAT
    "roles/compute.securityAdmin",           # step 2: firewall rules
    "roles/container.admin",                 # step 3 + 5: GKE and in-cluster RBAC for Helm
    "roles/iam.serviceAccountAdmin",         # step 3/4: node + workload SAs
    "roles/iam.serviceAccountUser",          # step 3: attach the node SA to VMs
    "roles/resourcemanager.projectIamAdmin", # step 3/4: grant roles to those SAs
    "roles/secretmanager.admin",             # step 4
    "roles/storage.admin",                   # C1: Cloud Batch data bucket
    "roles/artifactregistry.admin",          # C3: Docker Hub remote repo + its IAM


  ]
}

resource "google_project_iam_member" "ci" {
  for_each = toset(local.ci_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.ci.member
}

# State bucket: read/write state objects and the .tflock file - nothing else.
resource "google_storage_bucket_iam_member" "ci_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci.member
}
