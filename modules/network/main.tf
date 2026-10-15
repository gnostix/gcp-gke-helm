# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "google_compute_network" "this" {
  project = var.project_id
  name    = "${var.name}-vpc"

  # "Custom mode": no auto-created subnet in every region. We decide the IP plan.
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  # Remove the 0.0.0.0/0 default route to the internet gateway? No - Cloud NAT
  # needs it. Private nodes have no external IP, so the route alone exposes nothing.
  delete_default_routes_on_create = false
}

# -----------------------------------------------------------------------------
# Subnet with secondary ranges (VPC-native / alias IP)
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "this" {
  project = var.project_id
  name    = "${var.name}-${var.region}"
  region  = var.region
  network = google_compute_network.this.id # implicit dependency on the VPC

  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  # Nodes without public IPs can still reach Google APIs (Artifact Registry,
  # Secret Manager, Cloud Storage...) over Google's network, not via NAT.
  private_ip_google_access = true

  # VPC Flow Logs are useful but billed by volume - left off for the lab.
  # log_config { aggregation_interval = "INTERVAL_5_SEC"; flow_sampling = 0.5 }
}

# -----------------------------------------------------------------------------
# Cloud Router + Cloud NAT: outbound internet for private nodes
# (pulling images from Docker Hub / GitHub, apt, pip...). Inbound stays closed.
# OPTIONAL (var.enable_nat): ~$0.0014/VM-hour + $0.005/IP-hour + $0.045/GiB.
# Router and NAT are regional resources - there is no zonal (cheaper) variant.
# -----------------------------------------------------------------------------
resource "google_compute_router" "this" {
  # count = 0 or 1 is the Terraform idiom for an optional resource.
  # The resource then becomes a list: google_compute_router.this[0]
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${var.name}-nat"
  region  = var.region
  router  = google_compute_router.this[0].name

  nat_ip_allocate_option = "AUTO_ONLY" # Google picks/scales the external IPs

  # NAT only our subnet - all of its ranges, so pods (secondary range) get
  # egress too, not just the node VMs.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.this.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY" # port exhaustion etc. - cheap and the logs you actually need
  }
}

# -----------------------------------------------------------------------------
# Firewall
# Every VPC has two implied rules: allow ALL egress, deny ALL ingress.
# GKE itself creates the rules it needs (control plane -> nodes, pod-to-pod).
# We only add SSH via Identity-Aware Proxy, for debugging nodes.
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "iap_ssh" {
  project = var.project_id
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.this.id

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # Google's IAP TCP-forwarding range
  target_tags   = [var.node_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
