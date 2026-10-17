# -----------------------------------------------------------------------------
# One Helm release = one installed instance of a chart, tracked by Helm inside
# the cluster (a Secret in the namespace holds its history: `helm history`).
# Terraform's helm provider drives Helm's install/upgrade/uninstall for us.
# -----------------------------------------------------------------------------
resource "helm_release" "this" {
  name      = var.release_name
  namespace = var.namespace

  # Local chart in this repo. path.root = the root module's directory, so the
  # path works no matter where this module lives.
  chart = "${path.root}/charts/demo-app"

  create_namespace = true # the namespace has no other owner yet

  # Values override the chart's values.yaml. yamlencode() turns a Terraform
  # object into YAML, so we keep types and avoid string-escaping problems.
  values = [
    yamlencode({
      serviceAccount = {
        name = var.service_account
      }
      secret = {
        resourceName = var.secret_resource
      }
      message = var.message
    })
  ]

  # Wait until the Deployment is Ready (pod running, readiness probe passing).
  # If the secret can't be mounted, the apply fails here - visible in CI.
  wait    = true
  timeout = 300 # seconds
}
