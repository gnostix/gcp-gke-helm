# -----------------------------------------------------------------------------
# A 3rd-party chart from a public OCI registry (GitHub Container Registry).
# Same resource type as Step 5 - only the chart SOURCE differs:
#   Step 5:  chart = "<local path>"
#   here:    repository = "oci://…" + chart = "<name>" + version = "<exact>"
# -----------------------------------------------------------------------------
resource "helm_release" "this" {
  name             = "podinfo"
  namespace        = var.namespace
  create_namespace = true

  repository = "oci://ghcr.io/stefanprodan/charts"
  chart      = "podinfo"
  version    = var.chart_version # upgrades happen only when YOU change this

  # values = the chart's values.yaml keys you want to override. Look them up
  # with:  helm show values oci://ghcr.io/stefanprodan/charts/podinfo --version X
  # Anything not listed keeps the chart's default.
  values = [
    yamlencode({
      replicaCount = 1

      ui = {
        message = var.message
      }

      # The chart only sets requests by default (1m CPU / 16Mi) and no limits.
      # Always set both for 3rd-party software: protects the shared Spot node.
      resources = {
        requests = { cpu = "10m", memory = "32Mi" }
        limits   = { cpu = "100m", memory = "64Mi" }
      }

      service = {
        type = "ClusterIP" # internal only - no billed load balancer
      }
    })
  ]

  # `set` = override ONE key by its dotted path. Applied AFTER `values`,
  # so it wins on conflicts. Handy for single knobs; prefer `values` for
  # anything structured. (helm provider v3: a list of objects.)
  set = [
    {
      name  = "ui.color"
      value = var.color
    }
  ]

  wait    = true
  timeout = 300
}
