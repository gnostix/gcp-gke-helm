variable "project_id" {
  description = "Project where Batch jobs run."
  type        = string
}

variable "region" {
  description = "Region for the data bucket and the Batch jobs."
  type        = string
}

variable "name" {
  description = "Prefix for resource names (3-20 chars)."
  type        = string
}

variable "network_id" {
  description = "VPC id (projects/<p>/global/networks/<n>) - the format Batch jobs expect."
  type        = string
}

variable "subnet_id" {
  description = "Subnet id (projects/<p>/regions/<r>/subnetworks/<s>). Needs Private Google Access, because job VMs get no external IP."
  type        = string
}

variable "submitters" {
  description = "Principals allowed to submit jobs, e.g. [\"serviceAccount:ci@p.iam.gserviceaccount.com\"]. They can run jobs ONLY as the runner SA."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.submitters : can(regex("^(user|group|serviceAccount|domain):", m))])
    error_message = "Each submitter must start with user:, group:, serviceAccount: or domain:."
  }
}

variable "data_retention_days" {
  description = "Objects in the data bucket are deleted after this many days."
  type        = number
  default     = 3
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete the bucket even if it holds objects (lab: true)."
  type        = bool
  default     = true
}
