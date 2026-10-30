output "enabled_services" {
  value = sort(keys(google_project_service.this))
}

output "network" {
  description = "Network module outputs (consumed by GKE in Step 3)."
  value = {
    vpc            = module.network.network_name
    subnet         = module.network.subnet_name
    pods_range     = module.network.pods_range_name
    services_range = module.network.services_range_name
    node_tag       = module.network.node_tag
    nat_enabled    = module.network.nat_enabled
  }
}

output "gke" {
  value = {
    cluster      = module.gke.cluster_name
    location     = module.gke.location
    dns_endpoint = module.gke.dns_endpoint
    node_sa      = module.gke.node_service_account
  }
}

output "get_credentials" {
  description = "Run this to point kubectl at the cluster (via the DNS endpoint)."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --location ${module.gke.location} --project ${var.project_id} --dns-endpoint"
}

output "secrets" {
  value = {
    secret_id        = module.secrets.secret_id
    version_resource = module.secrets.secret_version_resource
    reader_principal = module.secrets.reader_principal
  }
}

output "app" {
  value = module.app.release
}

output "port_forward" {
  description = "Then open http://localhost:8080"
  value       = module.app.port_forward
}

output "podinfo" {
  value = module.podinfo.release
}

output "port_forward_podinfo" {
  description = "Then open http://localhost:9898"
  value       = module.podinfo.port_forward
}


output "gke_batch" {
  value = {
    kueue   = module.gke_batch.kueue
    queues  = module.gke_batch.queues
    kuberay = module.gke_batch.kuberay
  }
}


output "cloud_batch" {
  value = module.cloud_batch.job_settings
}