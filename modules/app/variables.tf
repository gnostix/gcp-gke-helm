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
