variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  description = "Prefix for every network resource name."
  type        = string
}

# --- IP plan -----------------------------------------------------------------
# A VPC-native GKE cluster uses THREE ranges from the same subnet:
#   primary         -> node VMs
#   secondary pods  -> one IP per pod (each node reserves a /24 by default)
#   secondary svcs  -> ClusterIP Services
# They must not overlap with each other or with anything you'll peer to later.

variable "subnet_cidr" {
  description = "Primary range: node IPs. /20 = 4096 addresses."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for pods. /16 = up to ~256 nodes at 110 pods/node (/24 each)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for Kubernetes Services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "node_tag" {
  description = "Network tag the GKE node pool will carry; firewall rules target it."
  type        = string
  default     = "gke-lab-node"
}

variable "enable_nat" {
  description = <<-EOT
    Create Cloud Router + Cloud NAT so PRIVATE nodes can reach the internet.
    false = cheapest: nodes get an ephemeral public IP instead (Step 3), no NAT
    gateway / per-GB processing fees. Ingress is still blocked by the firewall.
  EOT
  type        = bool
  default     = false
}
