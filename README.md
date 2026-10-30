# GKE lab — Terraform on GCP

Practice repo: Standard GKE + VPC + Secret Manager + a Helm-deployed app.

```
bootstrap/          one-time: GCS bucket for remote state (local state)
modules/
  network/          Step 2 - VPC, subnet + secondary ranges, Cloud NAT, firewall
  (gke)             Step 3 - now the shared module github.com/gnostix/terraform-google-gke (?ref=v2.0.0)
  secrets/          Step 4 - Secret Manager secret + IAM for the app
  app/              Step 5 - Helm release of a demo app reading the secret
*.tf                root stack: wires modules together
docs/               per-step explainers (open in a browser)
```

## Git hook (run once per clone)
```bash
git config core.hooksPath .githooks   # pre-commit: `terraform fmt` + `terraform validate` on touched stacks
```

## Prerequisites
terraform >= 1.9, gcloud, kubectl, helm, gke-gcloud-auth-plugin

```bash
gcloud auth login
gcloud auth application-default login   # credentials Terraform uses
gcloud config set project <PROJECT_ID>
```

## Cost profile (cheapest viable lab)
| Component | Choice | Why |
|---|---|---|
| GKE | **zonal** Standard cluster | free tier ($74.40/month credit) covers 1 zonal cluster's $0.10/h fee; regional is never covered |
| Nodes | 1 × e2-medium **Spot**, 30 GB pd-standard disk | Spot = 60-91% off; smallest disk/type that runs GKE system pods |
| Network | VPC/subnet/firewall free; **NAT off** (`enable_nat = false`) | public-IP nodes avoid NAT hourly + per-GB fees; ingress still denied |
| Secret Manager | 1 secret, single-region replica | 6 versions/month are free |
| App exposure | ClusterIP + `kubectl port-forward` | a LoadBalancer adds a billed forwarding rule |
| State bucket | regional, versioned | KB-sized, cents |

Always `terraform destroy` when you stop for the day: the node is the main cost.

## Step 1 — foundation
```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init && terraform apply
cd ..
cp backend.hcl.example backend.hcl              # bucket = output state_bucket
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan && terraform apply
```

## Step 2a — CI/CD with GitHub Actions (keyless)
```bash
cd bootstrap
echo 'github_repo = "<owner>/gcp-gke-helm"' >> terraform.tfvars
terraform apply                      # adds WIF pool/provider + CI service account
terraform output github_variables    # copy into GitHub repo Variables
cd ..
terraform providers lock -platform=darwin_arm64 -platform=linux_amd64   # lock file valid on CI runners
```
GitHub → Settings → Secrets and variables → Actions → **Variables**:
`GCP_PROJECT_ID`, `TF_STATE_BUCKET`, `GCP_WIF_PROVIDER`, `GCP_CI_SA`.
GitHub → Settings → Environments → create **gcp-lab** (optionally add yourself as required reviewer).
Workflow: `.github/workflows/terraform.yml` · Guide: `docs/02b-github-actions.html`

## Step 2 — network (deployed by CI)
Open a PR with the network code → review the plan comment → merge → the workflow applies it.
Locally you can still `terraform plan` to experiment, but let CI do the `apply`.
Guide: `docs/02-network.html`

## Step 3 — GKE (zonal, 1 Spot node)
Branch `step-3-gke` → PR → review plan (expect 5 to add) → merge → CI applies (~8-12 min).
```bash
$(terraform output -raw get_credentials)   # kubectl via the DNS endpoint
kubectl get nodes -o wide
```
End of day: Actions → terraform → Run workflow (main) → **destroy**. Morning: → **apply**.
Guide: `docs/03-gke.html`

## Step 4 — Secret Manager
1. GitHub → Settings → Secrets and variables → Actions → **Secrets** → New repository secret `DEMO_SECRET`.
2. Locally (only for local `plan`): `export TF_VAR_demo_secret='…'`
3. Branch `step-4-secrets` → PR → plan (3 to add, 1 to change: the cluster add-on) → merge.
Guide: `docs/04-secrets.html`

## Step 5 — Helm demo app
```bash
terraform init -backend-config=backend.hcl            # adds the helm provider + module.app
terraform providers lock -platform=darwin_arm64 -platform=linux_amd64
helm lint charts/demo-app --set secret.resourceName=x  # optional local chart check
```
Branch `step-5-helm` → PR → plan (1 to add: helm_release) → merge.
```bash
$(terraform output -raw port_forward)   # then http://localhost:8080
```
Guide: `docs/05-helm.html`

## Publishing charts (5c)
Charts in `charts/` are published as OCI artifacts to Artifact Registry
(`oci://europe-west1-docker.pkg.dev/<project>/charts`, created in `bootstrap/`).
- Workflow `.github/workflows/chart.yml`: on PRs it lints and checks the version; on merge to `main` it pushes.
- The registry has **immutable tags**: a changed chart must bump `version` in `Chart.yaml`, or the PR check fails.
- Requires the GitHub variable `CHART_REGISTRY` (= `terraform -chdir=bootstrap output chart_registry` without `oci://`).
```bash
helm show chart oci://europe-west1-docker.pkg.dev/<project>/charts/demo-app --version 0.2.0
```
## Deploying a chart version (5c)
`module "app"` installs `demo-app` from Artifact Registry with a pinned `chart_version` (root `main.tf`).
- **Build** (publish): change `charts/**` + bump `version` in `Chart.yaml` → `chart.yml` pushes it.
- **Release** (deploy): change `chart_version` in `main.tf` → `terraform.yml` plans/applies it.
- **Rollback**: a PR setting `chart_version` back to an older published version.

Local `terraform plan` needs a registry login first (token valid ~1 h):
```bash
gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin europe-west1-docker.pkg.dev
```

## Step 5b — public chart (podinfo), pinned version
Branch `step-5b-podinfo` → PR → plan (1 to add: module.podinfo.helm_release.this) → merge.
```bash
$(terraform output -raw port_forward_podinfo)   # then http://localhost:9898
helm -n podinfo list                             # CHART podinfo-6.14.1
```
Exercise: bump `chart_version` to `6.15.0` in a new PR and read the upgrade plan.
Guide: `docs/05b-podinfo.html`

## Shared GKE module (Phase 4)
`module "gke"` now comes from `git::https://github.com/gnostix/terraform-google-gke.git?ref=v2.0.0`.
The local `modules/gke/` was removed; the lab passes its cheap profile explicitly
(spot, pd-standard 30 GB, deletion_protection=false, system-only logging, no Prometheus, Secret Manager add-on).
Upgrade = change `?ref=` in a PR → `terraform init` → read the plan.

## Kueue exercise — batch queue on the Spot pool
Kueue 0.20.3 (`modules/gke-batch`, release `kueue`) + our queues (`charts/batch-queues`, release `batch-queues`).
```bash
kubectl create -f examples/jobs/sample-job.yaml          # submit (repeat to exceed the quota)
kubectl -n batch-jobs get workloads                      # Kueue: ADMITTED / pending
kubectl get clusterqueue batch                           # PENDING WORKLOADS / ADMITTED WORKLOADS
kubectl get nodes -L pool -w                             # batch nodes 0 → 1..2 → 0 (~10 min after jobs finish)
```
**Before the evening destroy:** `kubectl -n batch-jobs delete jobs --all`. Kueue's finalizers can block
uninstall while jobs exist. Uninstalling the `kueue` release also deletes its CRDs and all queue objects.

## Teardown
`terraform destroy` in the root, then (optionally) in `bootstrap/`
(empty the bucket first — `force_destroy = false` protects it).
