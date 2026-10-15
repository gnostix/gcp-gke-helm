# Outputs are the module's public API: the GKE module will consume these.
output "network_id" {
  value = google_compute_network.this.id
}

output "network_name" {
  value = google_compute_network.this.name
}

output "subnet_id" {
  value = google_compute_subnetwork.this.id
}

output "subnet_name" {
  value = google_compute_subnetwork.this.name
}

output "pods_range_name" {
  value = google_compute_subnetwork.this.secondary_ip_range[0].range_name
}

output "services_range_name" {
  value = google_compute_subnetwork.this.secondary_ip_range[1].range_name
}

output "node_tag" {
  value = var.node_tag
}

output "nat_enabled" {
  description = "Step 3 uses this to decide private vs public nodes."
  value       = var.enable_nat
}
