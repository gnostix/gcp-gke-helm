# -----------------------------------------------------------------------------
# Artifact Registry for Helm charts (exercise 5c)
#
# Lives in bootstrap, NOT in the main stack: the main stack is destroyed every
# evening, but published charts must survive - the morning apply installs
# them from here. Same reasoning as the state bucket.
#
# Helm 3 stores charts as OCI artifacts, so the repository format is DOCKER.
#   push:  helm push demo-app-0.2.0.tgz oci://europe-west1-docker.pkg.dev/<project>/charts
#   pull:  oci://europe-west1-docker.pkg.dev/<project>/charts/demo-app  --version 0.2.0
# -----------------------------------------------------------------------------
resource "google_artifact_registry_repository" "charts" {
  location      = var.region
  repository_id = "charts"
  format        = "DOCKER"
  description   = "Helm charts (OCI) for the GKE lab"

  # A published version can never be overwritten (like the v* tag ruleset on
  # the GKE module repo): demo-app:0.2.0 always means the same bytes.
  # Changed chart => bump Chart.yaml version.
  docker_config {
    immutable_tags = true
  }

  depends_on = [google_project_service.bootstrap]
}

locals {
  # host/project/repository - the part after oci://
  chart_registry = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.charts.repository_id}"
}

# CI publishes charts (chart workflow) and Terraform's helm provider pulls them.
# writer = push + pull, on THIS repository only (not project-wide).
resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  location   = google_artifact_registry_repository.charts.location
  repository = google_artifact_registry_repository.charts.name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.ci.member
}
