locals {
  # What the job VM needs: report task state to Batch, write logs.
  runner_project_roles = [
    "roles/batch.agentReporter",
    "roles/logging.logWriter",
  ]

  # What a submitter needs at project level: create/watch/delete jobs, read logs.
  submitter_project_roles = [
    "roles/batch.jobsEditor",
    "roles/logging.viewer",
  ]

  # setproduct -> every (member, role) pair; map key must be unique and stable.
  submitter_project_bindings = {
    for pair in setproduct(var.submitters, local.submitter_project_roles) :
    "${pair[0]}|${pair[1]}" => { member = pair[0], role = pair[1] }
  }
}

# --- Runner -------------------------------------------------------------------
resource "google_project_iam_member" "runner" {
  for_each = toset(local.runner_project_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.runner.member
}

resource "google_storage_bucket_iam_member" "runner_data" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectAdmin" # this bucket only
  member = google_service_account.runner.member
}

# --- Submitters (empty until C4) ------------------------------------------------
resource "google_project_iam_member" "submitter" {
  for_each = local.submitter_project_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# The key control: actAs on THIS SA only. A job's serviceAccount must be one the
# submitter can act as - so submitters can never borrow a more powerful identity.
resource "google_service_account_iam_member" "submitter_act_as" {
  for_each = toset(var.submitters)

  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

resource "google_storage_bucket_iam_member" "submitter_data" {
  for_each = toset(var.submitters)

  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectAdmin" # upload inputs, download outputs
  member = each.value
}
