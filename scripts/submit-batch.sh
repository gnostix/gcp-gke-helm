#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Submit a Cloud Batch job from a template in batch-jobs/.
#
#   scripts/submit-batch.sh batch-jobs/hello-script.json [job-name]
#
# Templates hold placeholders (__REGION__, __SERVICE_ACCOUNT__, __NETWORK__,
# __SUBNETWORK__, __BUCKET__). Real values come from Terraform's root output
# "cloud_batch", so no project-specific value is ever committed.
# Needs: terraform (with access to the state), jq, gcloud.
#
# PROVISIONING_MODEL=SPOT scripts/submit-batch.sh ...   (default: STANDARD)
# Spot jobs fail in Batch's pre-check on this free-trial project (works on GKE).
# -----------------------------------------------------------------------------
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $0 <template.json> [job-name]" >&2; exit 2; }

# Absolute template path, then run from the repo root (where terraform lives).
TEMPLATE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$(dirname "$0")/.."

# Job names: lowercase letters, digits, hyphens; start with a letter; <= 63.
BASE="$(basename "$TEMPLATE" .json)"
JOB_NAME="${2:-${BASE}-$(date +%Y%m%d-%H%M%S)}"

SETTINGS="$(terraform output -json cloud_batch)"
get() { jq -r ".$1" <<<"$SETTINGS"; }

PROJECT_ID="$(get project_id)"
REGION="$(get region)"

PROVISIONING_MODEL="${PROVISIONING_MODEL:-SPOT}"
case "$PROVISIONING_MODEL" in
  STANDARD|SPOT) ;;
  *) echo "PROVISIONING_MODEL must be STANDARD or SPOT" >&2; exit 2 ;;
esac

RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT

# "|" as sed delimiter: the values contain "/".
sed -e "s|__REGION__|${REGION}|g" \
    -e "s|__SERVICE_ACCOUNT__|$(get service_account)|g" \
    -e "s|__NETWORK__|$(get network)|g" \
    -e "s|__SUBNETWORK__|$(get subnetwork)|g" \
    -e "s|__BUCKET__|$(get bucket)|g" \
    -e "s|__PROVISIONING_MODEL__|${PROVISIONING_MODEL}|g" \
    "$TEMPLATE" > "$RENDERED"

# Fail early instead of sending a half-filled job to the API.
if grep -q '__[A-Z_]*__' "$RENDERED"; then
  echo "Unfilled placeholders in $TEMPLATE:" >&2
  grep -o '__[A-Z_]*__' "$RENDERED" | sort -u >&2
  exit 1
fi
jq empty "$RENDERED" # valid JSON?

echo "Submitting ${JOB_NAME} to ${REGION} ..."
gcloud batch jobs submit "$JOB_NAME" \
  --project "$PROJECT_ID" \
  --location "$REGION" \
  --config "$RENDERED" \
  --format="value(name,uid)"

cat <<EOF

Watch:
  gcloud batch jobs describe ${JOB_NAME} --location ${REGION} --format='value(status.state)'
  gcloud batch tasks list --job ${JOB_NAME} --location ${REGION}
EOF
