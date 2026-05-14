#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — Falco runtime security. DaemonSet, custom rules, shell-spawn alert.
# ABOUTME: Triggers a real Falco alert via kubectl exec and shows it surface in logs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — Falco runtime security"
context_card
require_cmd kubectl
require_ns security || exit 1

section "Falco DaemonSet on every node"
run kubectl get ds -n security -l app.kubernetes.io/name=falco
ds_desired=$(kubectl get ds -n security -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].status.desiredNumberScheduled}' 2>/dev/null || echo 0)
ds_ready=$(kubectl get ds -n security -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].status.numberReady}' 2>/dev/null || echo 0)
if [[ "${ds_ready}" -ge "${ds_desired}" && "${ds_desired}" -ge 1 ]]; then
    ok "${ds_ready}/${ds_desired} Falco pods Ready"
else
    fail "${ds_ready}/${ds_desired} Falco pods Ready"
fi

section "Custom rules loaded (configmap)"
if kubectl get cm -n security -l app.kubernetes.io/name=falco -o name 2>/dev/null | grep -q rules; then
    ok "custom rules ConfigMap present"
else
    warn "no custom-rules ConfigMap found — chart defaults only"
fi

section "Trigger a Falco alert: kubectl exec into an apps pod"
pod=$(kubectl get pods -n apps -l app=sample-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "${pod}" ]]; then
    warn "no sample-app pod found in apps namespace; using first apps pod"
    pod=$(kubectl get pods -n apps -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi
if [[ -z "${pod}" ]]; then
    fail "no pods in apps namespace to exec into"
    exit 1
fi
info "target pod: ${pod}"
narrate kubectl exec -n apps "${pod}" -- /bin/sh -c 'echo demo-shell-spawn'
if kubectl exec -n apps "${pod}" -- /bin/sh -c 'echo demo-shell-spawn' >/dev/null 2>&1; then
    allow "shell-spawn completed; Falco should have fired"
else
    info "shell-spawn rejected by image (no /bin/sh)? trying /bin/bash"
    kubectl exec -n apps "${pod}" -- /bin/bash -c 'echo demo-shell-spawn' >/dev/null 2>&1 || true
fi

section "Falco alert in the DaemonSet logs (last 30 lines)"
sleep 3
narrate kubectl logs -n security -l app.kubernetes.io/name=falco --tail=30 '|' grep -i 'shell\|spawned\|notice\|warning'
matches=$(kubectl logs -n security -l app.kubernetes.io/name=falco --tail=30 2>/dev/null \
          | grep -ciE 'shell|spawned|notice|warning' || true)
if [[ "${matches}" -gt 0 ]]; then
    ok "Falco fired ${matches} alert line(s) — runtime detection working"
    kubectl logs -n security -l app.kubernetes.io/name=falco --tail=30 2>/dev/null \
        | grep -iE 'shell|spawned|notice|warning' | head -5 | sed 's/^/    /'
else
    warn "no alert lines matched filter — alerts may take a few more seconds or use different priority"
    echo "    Inspect: kubectl logs -n security -l app.kubernetes.io/name=falco --tail=50"
fi

printf '\n'
banner "Phase 3 complete (Falco)"
