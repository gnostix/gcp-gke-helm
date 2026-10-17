variable "project_id" {
  type = string
}

variable "name" {
  description = "Cluster name (also prefix for the node pool and node SA)."
  type        = string
}

variable "zone" {
  description = "Zone for a ZONAL cluster: one control plane, nodes in one zone. Free-tier eligible."
  type        = string
}

# --- from the network module ---------------------------------------------------
variable "network_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "node_tag" {
  description = "Network tag on nodes; the IAP-SSH firewall rule targets it."
  type        = string
}

variable "private_nodes" {
  description = "true = nodes get no external IP (needs Cloud NAT for internet egress)."
  type        = bool
  default     = false
}

# --- node pool (cheap defaults) ------------------------------------------------
variable "machine_type" {
  description = "e2-medium (2 shared vCPU, 4 GB) is the smallest type that comfortably runs GKE system pods + a small app."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "spot" {
  description = "Spot VMs: 60-91% cheaper, can be reclaimed at any time (GKE recreates the node)."
  type        = bool
  default     = true
}

variable "disk_type" {
  type    = string
  default = "pd-standard"
}

variable "disk_size_gb" {
  type    = number
  default = 30
}

variable "release_channel" {
  description = "RAPID | REGULAR | STABLE - GKE auto-upgrades the control plane and nodes within the channel."
  type        = string
  default     = "REGULAR"
}
