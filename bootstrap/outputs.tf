output "state_bucket" {
  description = "Put this value in ../backend.hcl"
  value       = google_storage_bucket.tfstate.name
}
