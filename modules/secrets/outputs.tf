output "secret_id" {
  value = google_secret_manager_secret.demo.secret_id
}

output "secret_version_resource" {
  description = "What the SecretProviderClass references in Step 5."
  value       = "projects/${var.project_id}/secrets/${google_secret_manager_secret.demo.secret_id}/versions/latest"
}

output "reader_principal" {
  description = "The Workload Identity principal allowed to read the secret."
  value       = local.ksa_principal
}

output "k8s_namespace" {
  value = var.k8s_namespace
}

output "k8s_service_account" {
  value = var.k8s_service_account
}
