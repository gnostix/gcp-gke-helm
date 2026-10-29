# -----------------------------------------------------------------------------
# PriorityClass for platform controllers (Kueue). Without it Kueue runs at
# priority 0 and is the first pod evicted when system pods (kube-dns,
# konnectivity-agent) scale up with the node count - which blocks ALL Job
# creation, because Kueue's webhook is failurePolicy=Fail.
# 1000000: above normal workloads (0), below GKE system-* (~2e9).
# -----------------------------------------------------------------------------
resource "kubernetes_priority_class_v1" "platform_critical" {
  metadata {
    name = "platform-critical"
  }

  value          = 1000000
  global_default = false
  description    = "Platform controllers (Kueue): never evicted for normal workloads."
}

# -----------------------------------------------------------------------------
# Kueue controller configuration (trainloop-style scoping).
# controllerManagerConfigYaml is ONE string -> Helm can't merge it, so this is
# the FULL config: upstream 0.20.3 defaults + our three changes (marked).
# -----------------------------------------------------------------------------
locals {
  kueue_config = {
    apiVersion = "config.kueue.x-k8s.io/v1beta2"
    kind       = "Configuration"

    # --- upstream defaults (unchanged) ---------------------------------------
    health         = { healthProbeBindAddress = ":8081" }
    metrics        = { bindAddress = ":8443" }
    webhook        = { port = 9443 }
    leaderElection = { leaderElect = true, resourceName = "c1f6bfd2.kueue.x-k8s.io" }
    controller = {
      groupKindConcurrency = {
        "Job.batch"                     = 5
        "Pod"                           = 5
        "Workload.kueue.x-k8s.io"       = 10
        "LocalQueue.kueue.x-k8s.io"     = 5
        "Cohort.kueue.x-k8s.io"         = 1
        "ClusterQueue.kueue.x-k8s.io"   = 5
        "ResourceFlavor.kueue.x-k8s.io" = 1
      }
    }
    clientConnection = { qps = 300, burst = 500 }

    # --- CHANGE 1: only these namespaces are managed. Also becomes the
    # webhooks' namespaceSelector -> a Kueue outage can't block other namespaces.
    managedJobsNamespaceSelector = {
      matchExpressions = [{
        key      = "kubernetes.io/metadata.name"
        operator = "In"
        values   = [var.queues_namespace, var.training_namespace]
      }]
    }

    # --- CHANGE 2: explicit (it's the default). Jobs without a queue-name label
    # are not queued - e.g. the launcher Jobs in "training" run immediately.
    manageJobsWithoutQueueName = false

    # --- CHANGE 3: only the integrations we use. Drops pod/deployment/
    # statefulset, whose webhooks would otherwise be failurePolicy=Fail.
    integrations = {
      frameworks = ["batch/job", "ray.io/rayjob"]
    }
  }
}

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
      managerConfig = {
        controllerManagerConfigYaml = yamlencode(local.kueue_config)
      }

      controllerManager = {
        manager = {
          priorityClassName = kubernetes_priority_class_v1.platform_critical.metadata[0].name

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

# -----------------------------------------------------------------------------
# Release 3: KubeRay operator - the EXECUTOR. Turns a RayJob into head/worker
# pods. Kueue (the GATE) already has the ray.io/rayjob integration enabled by
# default; once these CRDs exist, queue-labelled RayJobs are held suspended
# until Kueue admits them.
#
# CRDs ship in the chart's crds/ folder: Helm installs them once and never
# upgrades or deletes them (unlike Kueue's, which are templates).
# -----------------------------------------------------------------------------
resource "helm_release" "kuberay" {
  name             = "kuberay-operator"
  namespace        = var.kuberay_namespace
  create_namespace = true

  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "kuberay-operator"
  version    = var.kuberay_chart_version

  values = [
    yamlencode({
      # Watch only the training namespace (trainloop: trainloop-system only).
      watchNamespace = [var.training_namespace]

      # Same placement/protection as Kueue: always-on default pool, and not
      # evicted for normal workloads.
      nodeSelector      = { pool = "default" }
      priorityClassName = kubernetes_priority_class_v1.platform_critical.metadata[0].name

      # Chart sets only limits (100m/512Mi), so requests = limits. Ask for less.
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "512Mi" }
      }
    })
  ]

  wait    = true
  timeout = 600
}