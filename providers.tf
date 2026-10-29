provider "google" {
  project = var.project_id
  region  = var.region

  # Applied to every resource that supports labels -> easy cost tracking / cleanup.
  default_labels = local.labels
}

# -----------------------------------------------------------------------------
# Helm talks to the Kubernetes API of the cluster created in Step 3.
#  - host: the DNS-based endpoint -> works from GitHub runners (any IP), access
#    decided by IAM (container.clusters.connect), not by source IP.
#  - exec: run gke-gcloud-auth-plugin to get a short-lived token on demand.
#    Unlike a `token = data.google_client_config...access_token`, nothing ends
#    up in the saved plan file that CI uploads as an artifact.
#  - no cluster_ca_certificate: the DNS endpoint serves a publicly trusted
#    certificate (same as `gcloud ... get-credentials --dns-endpoint`).
# -----------------------------------------------------------------------------
provider "helm" {
  kubernetes = {
    host = "https://${module.gke.dns_endpoint}"
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

# -----------------------------------------------------------------------------
# Kubernetes provider: for plain cluster objects that don't belong in a chart
# (e.g. the PriorityClass Kueue needs BEFORE its chart is installed).
# Same auth as Helm: DNS endpoint + gke-gcloud-auth-plugin, no token in plan.
# Note: here `exec` is a BLOCK (in the Helm provider v3 it's an attribute).
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host = "https://${module.gke.dns_endpoint}"
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}