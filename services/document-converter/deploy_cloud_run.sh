#!/usr/bin/env bash
set -euo pipefail

region="${CLOUD_RUN_REGION:-asia-south1}"
repository="${ARTIFACT_REPOSITORY:-fluxshare}"
project="$(gcloud config get-value project 2>/dev/null)"

if [[ -z "$project" || "$project" == "(unset)" ]]; then
  echo "Select a Google Cloud project with gcloud config set project PROJECT_ID." >&2
  exit 1
fi
if [[ -z "${FLUXSHARE_ALLOWED_ORIGINS:-}" ]]; then
  echo "Set FLUXSHARE_ALLOWED_ORIGINS to the exact FluxShare HTTPS origins." >&2
  exit 1
fi

if ! gcloud artifacts repositories describe "$repository" --location "$region" >/dev/null 2>&1; then
  gcloud artifacts repositories create "$repository" \
    --repository-format=docker \
    --location="$region" \
    --description="FluxShare service images"
fi

image="$region-docker.pkg.dev/$project/$repository/fluxshare-converter:latest"
gcloud builds submit --tag "$image" .
gcloud run deploy fluxshare-converter \
  --image "$image" \
  --region "$region" \
  --allow-unauthenticated \
  --cpu 2 \
  --memory 2Gi \
  --concurrency 1 \
  --max-instances 3 \
  --timeout 900 \
  --set-env-vars "^@^ALLOWED_ORIGINS=$FLUXSHARE_ALLOWED_ORIGINS"

gcloud run services describe fluxshare-converter \
  --region "$region" \
  --format='value(status.url)'
