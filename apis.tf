# A fresh project has most APIs disabled. Enabling them in code makes the
# stack reproducible in any project.
locals {
  services = [
    "compute.googleapis.com",          # VPC, subnets, NAT, VMs behind GKE nodes
    "container.googleapis.com",        # GKE
    "secretmanager.googleapis.com",    # Secret Manager
    "iam.googleapis.com",              # service accounts
    "cloudresourcemanager.googleapis.com", # project-level IAM bindings
  ]
}

resource "google_project_service" "this" {
  for_each = toset(local.services)

  service = each.value

  # Don't turn the API off on `terraform destroy` - other things in the
  # project may depend on it, and re-enabling is slow.
  disable_on_destroy = false
}
