variable "kueue_namespace" {
  description = "Namespace for the Kueue controller."
  type        = string
  default     = "kueue-system"
}

variable "kueue_chart_version" {
  description = "Upstream Kueue chart version (oci://registry.k8s.io/kueue/charts/kueue). Pinned."
  type        = string
}

variable "queues_namespace" {
  description = "Namespace where users submit jobs (the LocalQueue lives here)."
  type        = string
  default     = "batch-jobs"
}

variable "queues_chart_repository" {
  description = "OCI repository of our batch-queues chart, e.g. oci://europe-west1-docker.pkg.dev/<project>/charts."
  type        = string
}

variable "queues_chart_version" {
  description = "batch-queues chart version. Pinned."
  type        = string
}
