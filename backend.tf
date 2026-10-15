# "Partial" backend config: the bucket name is supplied at init time
#   terraform init -backend-config=backend.hcl
# so the same code can point at different buckets (dev / prod / your lab).
terraform {
  backend "gcs" {
    prefix = "gke-lab" # folder inside the bucket -> gke-lab/default.tfstate
  }
}
