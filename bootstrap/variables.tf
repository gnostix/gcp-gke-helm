variable "project_id" {
  description = "Existing GCP project to deploy the lab into."
  type        = string
}

variable "region" {
  description = "Region for the state bucket (and, later, the cluster)."
  type        = string
  default     = "europe-west1"
}

variable "github_repo" {
  description = "GitHub repo allowed to deploy, as \"owner/name\" (e.g. alexp/gcp-gke-helm)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must look like owner/name."
  }
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID. Deleted pools are kept 30 days and the ID can't be reused meanwhile - change this if you destroy and recreate."
  type        = string
  default     = "github"
}
