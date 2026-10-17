terraform {
  # 1.10 = ephemeral variables, 1.11 = write-only arguments (secret_data_wo)
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}
