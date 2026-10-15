variable "project_id" {
  description = "Existing GCP project to deploy the lab into."
  type        = string
}

variable "region" {
  description = "Region for the state bucket (and, later, the cluster)."
  type        = string
  default     = "europe-west1"
}
