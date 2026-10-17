# Root module: wires the building blocks together.
# Each step of the lab adds one module call here.

# -----------------------------------------------------------------------------
# Step 2 - Network
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network" # local path -> no download, `terraform init` just links it

  project_id = var.project_id
  region     = var.region
  name       = var.name
  node_tag   = "${var.name}-node"
  enable_nat = var.enable_nat

  # CIDRs use the module defaults (10.10/20 nodes, 10.20/16 pods, 10.30/20 services).

  # The compute API must be on before any VPC can be created. No attribute of
  # google_project_service is used inside the module, so make the order explicit.
  depends_on = [google_project_service.this]
}

# -----------------------------------------------------------------------------
# Step 3 - GKE (zonal Standard cluster, 1 Spot node)
# -----------------------------------------------------------------------------
module "gke" {
  source = "./modules/gke"

  project_id = var.project_id
  name       = var.name
  zone       = var.zone

  # Module outputs -> module inputs: this is how modules are wired together.
  # These references also give Terraform the order: network first, then GKE.
  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  node_tag            = module.network.node_tag

  # Private nodes only make sense when they have NAT for egress.
  private_nodes = var.enable_nat

  # Cheap defaults live in the module: e2-medium, Spot, 30 GB pd-standard, 1 node.

  depends_on = [google_project_service.this] # container.googleapis.com must be on
}

# Step 4 -> module "secrets"
# Step 5 -> module "app" (Helm)
