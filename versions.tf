terraform {
  required_version = ">= 1.11" # write-only args (Step 4)

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    # helm + kubernetes providers are added in Step 5.
  }
}
