#!/usr/bin/env bash
# ABOUTME: Build sample-app via Cloud Build and publish to BOTH Artifact Registry + Docker Hub.
# ABOUTME: Uses apps/sample-app/cloudbuild.yaml; no local docker daemon required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

readonly PROJECT="${PROJECT:-mrf-overall}"
readonly AR_IMAGE="us-east4-docker.pkg.dev/${PROJECT}/workshop/sample-app:1.0.0"
readonly DH_IMAGE="docker.io/peopleforrester/kcd-texas-sample-app:1.0.0"

usage() {
    cat <<EOF
Build sample-app and publish to both registries.

Usage: ${0##*/}

Targets (both pushed from a single Cloud Build run):
  Primary :  ${AR_IMAGE}
  Fallback:  ${DH_IMAGE}

Why two registries:
  - GCP Artifact Registry has no anonymous-pull rate limit (safer for 60
    student clusters pulling from the same conference NAT IP)
  - Docker Hub is the universally-known registry; documented fallback for
    forkers without GCP access

Prerequisites:
  - gcloud CLI authenticated with access to project ${PROJECT}
  - Secret Manager secret 'dockerhub-pat' with a Docker Hub PAT (workshop
    repo:write scope) — already created
  - Cloud Build SA has secretmanager.secretAccessor + artifactregistry.writer

Output: both registries will have the new :1.0.0 image after ~45 seconds.

EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

cd "${REPO_ROOT}"

printf "Submitting Cloud Build (builds once, pushes to both registries)...\n" >&2
gcloud builds submit apps/sample-app/ \
    --config=apps/sample-app/cloudbuild.yaml \
    --project="${PROJECT}"

printf "\nDone. Images live at:\n" >&2
printf "  %s\n" "${AR_IMAGE}" >&2
printf "  %s\n" "${DH_IMAGE}" >&2
