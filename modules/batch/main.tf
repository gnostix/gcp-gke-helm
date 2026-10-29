# -----------------------------------------------------------------------------
# Release 1: Kueue itself - CRDs (as templates), controller, admission webhooks.
# Installed DIRECTLY from the upstream registry (no wrapper), pinned version,
# lab-sized via values.
# -----------------------------------------------------------------------------
resource "helm_release" "kueue" {
  name             = "kueue"
  namespace        = var.kueue_namespace
  create_namespace = true

  repository = "oci://registry.k8s.io/kueue/charts"
  chart      = "kueue"
  version    = var.kueue_chart_version

  values = [
    yamlencode({
      controllerManager = {
        manager = {
          # Upstream default requests 500m / 512Mi - too much for the small
          # default node shared with the other apps.
          resources = {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
        }
        # Run the controller on the always-on default pool, never on the
        # batch pool (which scales to zero).
        nodeSelector = { pool = "default" }
      }
    })
  ]

  # Wait until the controller (and its webhook) is Ready: release 2 creates
  # Kueue objects, which the webhook must validate.
  wait    = true
  timeout = 600
}

# -----------------------------------------------------------------------------
# Release 2: our queue configuration (ResourceFlavor, ClusterQueue, LocalQueue)
# from our Artifact Registry. Separate release because its objects need the
# CRDs + webhook from release 1 to exist first.
# -----------------------------------------------------------------------------
resource "helm_release" "queues" {
  name             = "batch-queues"
  namespace        = var.queues_namespace
  create_namespace = true

  repository = var.queues_chart_repository
  chart      = "batch-queues"
  version    = var.queues_chart_version

  wait = true

  # Order on apply: kueue -> queues. On destroy (reverse): queues -> kueue,
  # so Kueue's finalizers are processed while the controller still runs.
  depends_on = [helm_release.kueue]
}
