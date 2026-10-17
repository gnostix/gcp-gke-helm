output "cluster_name" {
  value = google_container_cluster.this.name
}

output "location" {
  value = google_container_cluster.this.location
}

output "dns_endpoint" {
  description = "IAM-authorised control plane FQDN (used by CI in Step 5)."
  value       = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "workload_pool" {
  value = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "node_service_account" {
  value = google_service_account.nodes.email
}
