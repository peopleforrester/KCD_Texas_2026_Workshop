#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — Falcosidekick alert forwarder. Pods, /metrics endpoint, talon output.
# ABOUTME: Confirms Falcosidekick is wired to receive from Falco and forward to FalcoTalon.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — Falcosidekick alert forwarder"
context_card
require_cmd kubectl
require_ns security || exit 1

section "Falcosidekick pods Running"
run kubectl get pods -n security -l app.kubernetes.io/name=falcosidekick
total=$(pods_total security app.kubernetes.io/name=falcosidekick)
running=$(pods_running security app.kubernetes.io/name=falcosidekick)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} Falcosidekick pods Running"
else
    fail "${running}/${total} Falcosidekick pods Running"
fi

section "Service reachable on port 2801"
if kubectl get svc falcosidekick -n security >/dev/null 2>&1; then
    eps=$(kubectl get endpoints falcosidekick -n security -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [[ -n "${eps}" ]]; then
        ok "Service falcosidekick has endpoints: ${eps}"
    else
        fail "Service exists but no ready endpoints"
    fi
else
    fail "Service falcosidekick not found"
fi

section "Prometheus metrics endpoint"
pod=$(kubectl get pods -n security -l app.kubernetes.io/name=falcosidekick -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "${pod}" ]]; then
    narrate kubectl exec -n security "${pod}" -- wget -qO- http://localhost:2801/metrics '|' head -10
    if metrics=$(kubectl exec -n security "${pod}" -- wget -qO- http://localhost:2801/metrics 2>/dev/null); then
        echo "${metrics}" | head -8 | sed 's/^/    /'
        ok "/metrics endpoint responsive"
    else
        warn "wget not in image; falling back to ConfigMap check"
    fi
fi

section "Talon output wired in chart values"
if kubectl get cm -n security -o yaml 2>/dev/null | grep -q 'falco-talon.security.svc.cluster.local'; then
    allow "Sidekick config references falco-talon (output wired)"
else
    warn "no falco-talon address found in Sidekick ConfigMap — output may not be wired"
fi

section "Live: sidekick logs (forwarded events)"
narrate kubectl logs -n security -l app.kubernetes.io/name=falcosidekick --tail=15
kubectl logs -n security -l app.kubernetes.io/name=falcosidekick --tail=15 2>&1 | sed 's/^/    /' | head -20

printf '\n'
banner "Phase 3 complete (Falcosidekick)"
