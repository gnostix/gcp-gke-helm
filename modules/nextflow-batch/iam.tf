locals {
  head_project_roles = [
    "roles/batch.agentReporter", # VM agent reports task state
    "roles/batch.jobsEditor",    # the head job submits one Batch job per task
    "roles/logging.logWriter",
  ]

  seqera_project_roles = [
    "roles/batch.jobsEditor",                  # launch/monitor/cancel the head job
    "roles/logging.viewer",                    # show logs in the Seqera UI
    "roles/compute.viewer",                    # credential validation
    "roles/serviceusage.serviceUsageConsumer", # call APIs billed to this project
    "roles/storage.bucketViewer",              # storage.buckets.list - else credential INVALID
  ]
}

# --- Head job SA ----------------------------------------------------------------
resource "google_project_iam_member" "head" {
  for_each = toset(local.head_project_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.head.member
}

# Task jobs run as the head SA too -> the head must be allowed to "act as" itself.
resource "google_service_account_iam_member" "head_act_as_self" {
  service_account_id = google_service_account.head.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.head.member
}

resource "google_storage_bucket_iam_member" "head_data" {
  for_each = google_storage_bucket.this # keys: work, results

  bucket = each.value.name
  role   = "roles/storage.objectUser" # create/read/delete objects, no IAM changes
  member = google_service_account.head.member
}

# --- Seqera credential SA -------------------------------------------------------
resource "google_project_iam_member" "seqera" {
  for_each = toset(local.seqera_project_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.seqera.member
}

# Seqera may launch jobs ONLY as the head SA.
resource "google_service_account_iam_member" "seqera_act_as_head" {
  service_account_id = google_service_account.head.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.seqera.member
}

# Data Explorer download links are signed URLs -> the SA signs as itself.
resource "google_service_account_iam_member" "seqera_token_creator_self" {
  service_account_id = google_service_account.seqera.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_service_account.seqera.member
}

resource "google_storage_bucket_iam_member" "seqera_data" {
  for_each = google_storage_bucket.this

  bucket = each.value.name
  role   = "roles/storage.objectViewer" # UI shows reports/outputs, can't change them
  member = google_service_account.seqera.member
}

# The WIF link: identities from the Seqera pool may impersonate this SA.
# The pool's attribute condition (N3) already limits it to OUR workspace.
resource "google_service_account_iam_member" "seqera_wif" {
  count = var.wif_pool_name == null ? 0 : 1

  service_account_id = google_service_account.seqera.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.wif_pool_name}/*"
}
