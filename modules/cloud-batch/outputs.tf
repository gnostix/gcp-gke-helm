output "runner_service_account" {
  value = google_service_account.runner.email
}

output "data_bucket" {
  value = google_storage_bucket.data.name
}

# Everything a job definition needs. scripts/submit-batch.sh (C2) reads this.
output "job_settings" {
  value = {
    project_id      = var.project_id
    region          = var.region
    service_account = google_service_account.runner.email
    network         = var.network_id
    subnetwork      = var.subnet_id
    bucket          = google_storage_bucket.data.name
    image_registry  = "${google_artifact_registry_repository.dockerhub.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dockerhub.repository_id}"

  }
}
