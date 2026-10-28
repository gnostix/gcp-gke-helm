variable "project_id" {
  type = string
}

variable "region" {
  description = "Single replica location. Must match the cluster's region for the GKE Secret Manager add-on."
  type        = string
}

variable "name" {
  description = "Prefix for the secret ID."
  type        = string
}

# --- the secret value ---------------------------------------------------------
variable "secret_value" {
  description = "Secret payload. Supplied via TF_VAR_demo_secret (GitHub secret DEMO_SECRET), never a file."
  type        = string

  # sensitive: redacted in plan/apply output.
  sensitive = true
  # ephemeral: Terraform never persists it - not in state, not in the saved
  # plan file (which CI uploads as an artifact). It can only flow into
  # ephemeral contexts, such as a write-only argument.
  ephemeral = true

  validation {
    condition     = length(var.secret_value) > 0
    error_message = "secret_value is empty - set TF_VAR_demo_secret (locally) or the DEMO_SECRET GitHub secret (CI)."
  }
}

variable "secret_version" {
  description = "Bump this number to push a new secret_value as a new version (write-only values can't be diffed)."
  type        = number
  default     = 2
}

# --- who may read it ------------------------------------------------------------
variable "k8s_namespace" {
  description = "Namespace of the Kubernetes service account allowed to read the secret (created in Step 5)."
  type        = string
  default     = "demo"
}

variable "k8s_service_account" {
  description = "Name of the Kubernetes service account allowed to read the secret (created in Step 5)."
  type        = string
  default     = "demo-app"
}
