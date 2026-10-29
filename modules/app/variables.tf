variable "release_name" {
  description = "Helm release name (also used as Deployment/Service name)."
  type        = string
  default     = "demo-app"
}

variable "namespace" {
  description = "Namespace to install into - must match the namespace granted access in Step 4."
  type        = string
}

variable "service_account" {
  description = "Kubernetes SA the pod runs as - must match the principal granted access in Step 4."
  type        = string
}

variable "secret_resource" {
  description = "Secret Manager version to mount, e.g. projects/P/secrets/S/versions/latest."
  type        = string
}

variable "message" {
  description = "Text shown on the demo page."
  type        = string
  default     = "Hello from GKE, deployed by Terraform + Helm"
}


variable "chart_repository" {
  description = "OCI repository of the chart, e.g. oci://europe-west1-docker.pkg.dev/<project>/charts. null = install the local folder charts/demo-app (Step 5 behaviour)."
  type        = string
  default     = null
}

variable "chart_version" {
  description = "Exact chart version to install from chart_repository. Required when chart_repository is set."
  type        = string
  default     = null

  validation {
    # Cross-variable validation (Terraform >= 1.9): a registry without a pinned version is not allowed.
    condition     = var.chart_version != null || var.chart_repository == null
    error_message = "chart_version is required when chart_repository is set."
  }
}