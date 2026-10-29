terraform {
  required_version = ">= 1.11" # write-only args (Step 4)

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0" # 3.x: `kubernetes = { ... }` is an attribute, not a block
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}
