#!/usr/bin/env bash
# ABOUTME: Phase 1 demo — verify cluster foundation: nodes Ready, namespaces, metrics-server.
# ABOUTME: Uses current kubectl context; emits SUCCESS/FAILURE badges per check.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 1 — Cluster Foundation"
context_card
require_cmd kubectl

section "Nodes Ready"
run kubectl get nodes
ready=$(kubectl get nodes --no-headers 2>/dev/null \
        | awk '$2=="Ready"' | wc -l)
total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [[ "${ready}" -ge 2 && "${ready}" -eq "${total}" ]]; then
    ok "${ready}/${total} nodes Ready"
else
    fail "${ready}/${total} nodes Ready (workshop needs >=2)"
fi

section "Workshop namespaces exist"
for ns in argocd apps kyverno monitoring backstage security; do
    if kubectl get ns "${ns}" >/dev/null 2>&1; then
        allow "namespace ${ns} present"
    else
        deny "namespace ${ns} MISSING"
    fi
done

section "metrics-server installed (kubectl top works)"
if kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
    ok "metrics-server deployment found"
    run kubectl top nodes
else
    fail "metrics-server NOT installed — apply from kubernetes-sigs/metrics-server"
fi

section "kube-system base pods healthy"
total=$(pods_total kube-system)
running=$(pods_running kube-system)
if [[ "${total}" -gt 0 && "${running}" -eq "${total}" ]]; then
    ok "${running}/${total} kube-system pods Running/Succeeded"
else
    fail "${running}/${total} kube-system pods healthy"
fi

printf '\n'
banner "Phase 1 complete"
