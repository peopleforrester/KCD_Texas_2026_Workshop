#!/usr/bin/env bash
# ABOUTME: Build the sample-app image from apps/sample-app/ and push to a public registry.
# ABOUTME: Default target is ghcr.io/peopleforrester/kcd-texas-sample-app:1.0.0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults — override via env vars or args
readonly DEFAULT_REGISTRY="ghcr.io"
readonly DEFAULT_REPO="peopleforrester/kcd-texas-sample-app"
readonly DEFAULT_TAG="1.0.0"

REGISTRY="${REGISTRY:-${DEFAULT_REGISTRY}}"
REPO="${REPO:-${DEFAULT_REPO}}"
TAG="${TAG:-${DEFAULT_TAG}}"
FULL_IMAGE="${REGISTRY}/${REPO}:${TAG}"

usage() {
    cat <<EOF
Build and push the workshop sample-app image.

Usage: ${0##*/} [--push]

Environment variables (optional):
  REGISTRY   default: ${DEFAULT_REGISTRY}
  REPO       default: ${DEFAULT_REPO}
  TAG        default: ${DEFAULT_TAG}

Steps:
  1. docker build apps/sample-app/ → \${FULL_IMAGE}
  2. (if --push) docker push \${FULL_IMAGE}
  3. Print sed command to point gitops/manifests/sample-app/deployment.yaml
     at the new image instead of nginxinc/nginx-unprivileged.

Prerequisites:
  - docker daemon running
  - For GHCR: gh auth login (workshop already has this for peopleforrester)
    then: echo "\$(gh auth token)" | docker login ghcr.io -u peopleforrester --password-stdin

EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

push_flag=0
if [[ "${1:-}" == "--push" ]]; then
    push_flag=1
fi

cd "${REPO_ROOT}"

if ! command -v docker >/dev/null 2>&1; then
    printf "ERROR: docker not on PATH\n" >&2
    exit 1
fi

printf "Building %s from apps/sample-app/Dockerfile...\n" "${FULL_IMAGE}" >&2
docker build -t "${FULL_IMAGE}" apps/sample-app/

if [[ "${push_flag}" -eq 1 ]]; then
    printf "Pushing %s ...\n" "${FULL_IMAGE}" >&2
    docker push "${FULL_IMAGE}"
    printf "\nImage pushed. To wire the workshop manifest to use it:\n\n" >&2
    printf "  sed -i 's|nginxinc/nginx-unprivileged:alpine|%s|' \\\\\n" "${FULL_IMAGE}" >&2
    printf "    gitops/manifests/sample-app/deployment.yaml\n\n" >&2
    printf "Then: git add gitops/manifests/sample-app/deployment.yaml && git commit + push.\n" >&2
else
    printf "\nImage built locally (not pushed). Re-run with --push when ready.\n" >&2
fi
