# GKE lab — Terraform on GCP

Practice repo: Standard GKE + VPC + Secret Manager + a Helm-deployed app.

```
bootstrap/          one-time: GCS bucket for remote state (local state)
modules/
  network/          Step 2 - VPC, subnet + secondary ranges, Cloud NAT, firewall
  gke/              Step 3 - private Standard cluster, node pool, Workload Identity
  secrets/          Step 4 - Secret Manager secret + IAM for the app
  app/              Step 5 - Helm release of a demo app reading the secret
*.tf                root stack: wires modules together
docs/               per-step explainers (open in a browser)
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

## Step 2 — network
```bash
terraform init          # registers the new local module
terraform plan          # expect 3 to add: vpc, subnet, firewall (+ router, nat if enable_nat = true)
terraform apply
```
Guide: `docs/02-network.html`

## Teardown
`terraform destroy` in the root, then (optionally) in `bootstrap/`
(empty the bucket first — `force_destroy = false` protects it).
