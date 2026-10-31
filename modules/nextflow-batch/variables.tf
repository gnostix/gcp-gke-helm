variable "project_id" {
  description = "Project where Nextflow runs on Cloud Batch."
  type        = string
}

variable "region" {
  description = "Region for the buckets and the Batch jobs."
  type        = string
}

variable "name" {
  description = "Prefix for resource names (3-20 chars)."
  type        = string
}

variable "network_name" {
  description = "VPC name - Seqera's compute environment form asks for the name, not the id."
  type        = string
}

variable "subnet_name" {
  description = "Subnet name (same reason). Needs Cloud NAT: the head job reaches GitHub, Seqera and quay.io."
  type        = string
}

variable "work_retention_days" {
  description = "Nextflow work dir objects are deleted after this many days (intermediate files)."
  type        = number
  default     = 3
}

variable "results_retention_days" {
  description = "Published results are deleted after this many days (lab)."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete non-empty buckets (lab: true)."
  type        = bool
  default     = true
}

variable "wif_pool_name" {
  description = "Seqera WIF pool, projects/<NUMBER>/locations/global/workloadIdentityPools/<POOL>. null = no WIF binding yet (set in N3)."
  type        = string
  default     = null
}
