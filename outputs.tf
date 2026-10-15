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
