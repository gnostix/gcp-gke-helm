locals {
  labels = {
    env        = "lab"
    managed_by = "terraform"
    stack      = var.name
  }
}
