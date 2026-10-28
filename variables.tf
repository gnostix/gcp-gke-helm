variable "project_id" {
  description = "Existing GCP project to deploy the lab into."
  type        = string
}

variable "region" {
  description = "Region for network and (regional) GKE cluster."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone for the ZONAL GKE cluster (Step 3). Must be inside var.region."
  type        = string
  default     = "europe-west1-b"
}

variable "name" {
  description = "Short prefix used in every resource name."
  type        = string
  default     = "gke-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.name))
    error_message = "name must be 3-20 chars, lowercase letters, digits and hyphens."
  }
}

# --- Cost switches ------------------------------------------------------------
variable "enable_nat" {
  description = "true = private nodes + Cloud NAT (prod-like). false = public-IP nodes, no NAT (cheapest)."
  type        = bool
  default     = false
}

# --- Step 4: Secret Manager ---------------------------------------------------
variable "demo_secret" {
  description = "Demo secret value. CI: GitHub secret DEMO_SECRET. Laptop: export TF_VAR_demo_secret=..."
  type        = string
  sensitive   = true
  ephemeral   = true # never written to state or to saved plan files
}

variable "demo_secret_version" {
  description = "Bump to publish a new value of demo_secret as a new secret version."
  type        = number
  default     = 2 # 2: DEMO_SECRET changed (rotation)
}
