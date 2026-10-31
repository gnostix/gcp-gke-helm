# Everything the Seqera credential + compute environment forms ask for (N4).
output "seqera" {
  value = {
    credential_service_account = google_service_account.seqera.email
    head_job_service_account   = google_service_account.head.email
    work_dir                   = "gs://${google_storage_bucket.this["work"].name}"
    results_dir                = "gs://${google_storage_bucket.this["results"].name}"
    region                     = var.region
    vpc                        = var.network_name
    subnet                     = var.subnet_name
  }
}
