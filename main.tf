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
  # Shared, versioned module (Phase 4). ?ref pins an immutable release tag.
  # Upgrading = changing this ref in a PR and reading the plan.
  source = "git::https://github.com/gnostix/terraform-google-gke.git?ref=v1.1.0"

  project_id = var.project_id
  name       = var.name
  location   = var.zone # module input is `location`: a zone => zonal cluster

  # Module outputs -> module inputs: network first, then GKE.
  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  node_network_tags   = [module.network.node_tag]

  # Private nodes only make sense when they have NAT for egress.
  private_nodes = var.enable_nat

  # --- lab profile: everything that differs from the module's defaults ---------
  # (the module defaults are production-safe; the lab is cheap + disposable)
  deletion_protection         = false                 # default true
  spot                        = true                  # default false
  disk_type                   = "pd-standard"         # default pd-balanced
  disk_size_gb                = 30                    # default 100
  logging_components          = ["SYSTEM_COMPONENTS"] # default + WORKLOADS
  managed_prometheus          = false                 # default true
  enable_secret_manager_addon = true                  # default false (Step 4/5 need it)

  depends_on = [google_project_service.this] # container.googleapis.com must be on
}

# -----------------------------------------------------------------------------
# Step 4 - Secret Manager (+ access for a Kubernetes SA via Workload Identity)
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  project_id = var.project_id
  region     = var.region # same region as the zonal cluster - required by the GKE add-on
  name       = var.name

  secret_value   = var.demo_secret
  secret_version = var.demo_secret_version

  # Who may read it: the Kubernetes SA that Step 5's Helm chart will create.
  k8s_namespace       = "demo"
  k8s_service_account = "demo-app"

  # The Workload Identity pool (PROJECT.svc.id.goog) only exists once the
  # cluster does, and secretmanager.googleapis.com must be enabled.
  depends_on = [module.gke, google_project_service.this]
}

# -----------------------------------------------------------------------------
# Step 5 - Helm: a demo app that reads the Step 4 secret via the GKE add-on
# -----------------------------------------------------------------------------
module "app" {
  source = "./modules/app"

  # The SAME namespace/SA that Step 4 granted access to - read from the
  # secrets module's outputs so the two can never drift apart.
  namespace       = module.secrets.k8s_namespace
  service_account = module.secrets.k8s_service_account
  secret_resource = module.secrets.secret_version_resource

  # The IAM grant must exist before the pod tries to mount the secret.
  depends_on = [module.secrets]
}

# -----------------------------------------------------------------------------
# Step 5b - a public 3rd-party chart (podinfo) with a pinned version
# -----------------------------------------------------------------------------
module "podinfo" {
  source = "./modules/podinfo"

  # Pinned on purpose to the previous release: the follow-up exercise is to
  # bump it to "6.15.0" in a PR and read the upgrade plan.
  chart_version = "6.14.1"

  # No depends_on needed: helm_release depends on the helm provider, whose
  # configuration references module.gke - so the cluster always comes first.
}
