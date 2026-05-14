#!/usr/bin/env bash
# ABOUTME: Phase 5 demo — load-generator. Workshop substitute is nginx with TCP probe.
# ABOUTME: Pod Running confirms the platform deploys a "synthetic traffic" workload via GitOps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 5 — load-generator"
context_card
require_cmd kubectl
require_ns apps || exit 1

section "load-generator deployment"
run kubectl get deploy load-generator -n apps
total=$(pods_total apps app=load-generator)
running=$(pods_running apps app=load-generator)
if [[ "${running}" -ge 1 && "${running}" -eq "${total}" ]]; then
    ok "${running}/${total} load-generator pods Running"
else
    fail "${running}/${total} load-generator pods Running"
fi

section "Substitute image note"
img=$(kubectl get deploy load-generator -n apps -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo '')
case "${img}" in
    *nginx-unprivileged*)
        warn "image: ${img}"
        info "Workshop uses nginx-unprivileged as the public substitute for the kubeauto"
        info "load-generator image (which lives in a private ECR). The original generates"
        info "HTTP load against ecom-api; the substitute is a static Pod."
        info "To make this actually generate load, replace with a public load-gen image or"
        info "build a custom one (similar pattern to sample-app's build script)."
        ;;
    *)
        ok "image: ${img}"
        ;;
esac

section "Pod state + probe"
pod=$(kubectl get pods -n apps -l app=load-generator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo '')
if [[ -n "${pod}" ]]; then
    info "pod: ${pod}"
    ready=$(kubectl get pod "${pod}" -n apps -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
    if [[ "${ready}" == "true" ]]; then
        ok "container ready (TCP probe on :8080 passes)"
    else
        fail "container not ready"
    fi
fi

printf '\n'
banner "load-generator verified (workshop substitute)"
