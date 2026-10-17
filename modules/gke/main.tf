# -----------------------------------------------------------------------------
# Cluster (control plane)
# -----------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.zone # a ZONE => zonal cluster. A REGION here => regional (3x nodes, no free tier)

  # We manage nodes in our own node pool resource (below). GKE insists on
  # creating a default pool first, so create 1 node and delete it immediately.
  remove_default_node_pool = true
  initial_node_count       = 1

  # That throw-away default pool still needs a working SA: some projects have
  # the Compute default SA disabled or deleted. Point it at ours.
  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_type       = var.disk_type
    disk_size_gb    = var.disk_size_gb
  }

  # Lab: allow `terraform destroy`. Production: true (and/or deletion_policy = "PREVENT").
  deletion_protection = false

  # --- networking: VPC-native, ranges from Step 2 -----------------------------
  network         = var.network_id
  subnetwork      = var.subnet_id
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name     # pod IPs
    services_secondary_range_name = var.services_range_name # ClusterIP Services
  }

  # Private nodes only when NAT exists (enable_nat = true). The provider docs
  # recommend omitting this block entirely rather than setting it to false,
  # hence `dynamic` - a block that's rendered 0 or 1 times.
  dynamic "private_cluster_config" {
    for_each = var.private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
    }
  }

  # --- control plane access ---------------------------------------------------
  # DNS-based endpoint: a stable FQDN reachable from anywhere Google APIs are,
  # authorised by IAM (container.clusters.connect) instead of by source IP.
  # That's what lets GitHub-hosted runners (changing IPs) run Helm in Step 5.
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
    ip_endpoints_config {
      enabled = true # keep the classic IP endpoint too (nodes, older tooling)
    }
  }

  # --- identity -------------------------------------------------------------
  # Workload Identity: pods act as Google service accounts without keys (Step 4).
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # --- add-ons -----------------------------------------------------------------
  # Managed Secret Manager CSI driver: pods mount Secret Manager secrets as
  # files (driver secrets-store-gke.csi.k8s.io), authenticated by Workload
  # Identity. Google installs and upgrades it. Used in Step 4/5.
  secret_manager_config {
    enabled = true
  }

  # --- operations: upgrades & cost -------------------------------------------
  release_channel {
    channel = var.release_channel
  }

  # Only system logs/metrics - workload logs and Managed Prometheus cost money
  # by volume and aren't needed for the lab.
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false
    }
  }

  lifecycle {
    # node_config above only shapes the deleted default pool; once that pool
    # is gone the API reports different values, which would cause endless diffs.
    ignore_changes = [node_config]
  }

  depends_on = [google_project_iam_member.nodes]
}

# -----------------------------------------------------------------------------
# Node pool
# Separate resource => you can change/replace nodes without touching the
# control plane, and add more pools later (e.g. a GPU pool for scientific jobs).
# -----------------------------------------------------------------------------
resource "google_container_node_pool" "default" {
  project  = var.project_id
  name     = "${var.name}-pool"
  location = var.zone
  cluster  = google_container_cluster.this.name

  node_count = var.node_count

  management {
    auto_repair  = true # recreate unhealthy nodes (also covers Spot reclaims)
    auto_upgrade = true # follow the release channel
  }

  node_config {
    machine_type = var.machine_type
    spot         = var.spot
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb
    image_type   = "COS_CONTAINERD" # Container-Optimized OS: minimal, auto-patched

    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"] # access is limited by IAM, not scopes

    tags = [var.node_tag]

    labels = {
      pool = "default"
    }

    # Pods see the GKE metadata server (Workload Identity) instead of the
    # node's own credentials.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
