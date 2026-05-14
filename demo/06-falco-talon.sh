#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — FalcoTalon end-to-end auto-response.
# ABOUTME: Trigger Falco alert via shell-spawn, watch Talon terminate the offending pod.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — FalcoTalon end-to-end auto-response"
context_card
require_cmd kubectl
require_ns security || exit 1
require_ns apps || exit 1

section "FalcoTalon pod Running"
run kubectl get pods -n security -l app.kubernetes.io/name=falco-talon
total=$(pods_total security app.kubernetes.io/name=falco-talon)
running=$(pods_running security app.kubernetes.io/name=falco-talon)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} FalcoTalon pods Running"
else
    fail "${running}/${total} FalcoTalon pods Running"
    exit 1
fi

section "Service falco-talon:2803 — endpoint Sidekick forwards to"
if eps=$(kubectl get endpoints falco-talon -n security -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null) && [[ -n "${eps}" ]]; then
    ok "endpoints: ${eps}"
else
    fail "no ready endpoints on falco-talon Service"
    exit 1
fi

section "Rules loaded (default: kubernetes:terminate on match)"
narrate kubectl get cm -n security falco-talon-rules -o jsonpath='{.data}'
kubectl get cm -n security falco-talon-rules -o jsonpath='{.data}' 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('rules.yaml','(empty)'))" 2>/dev/null \
    | head -12 | sed 's/^/    /'

pause

section "Set up a sacrificial pod to terminate"
narrate kubectl run talon-victim --image=nginx:alpine -n apps --restart=Never \
    --labels=app=talon-victim,team=workshop \
    --overrides='{"spec":{"containers":[{"name":"talon-victim","image":"nginx:alpine","resources":{"requests":{"cpu":"50m","memory":"32Mi"},"limits":{"cpu":"100m","memory":"64Mi"}}}]}}'
if kubectl run talon-victim --image=nginx:alpine -n apps --restart=Never \
    --labels=app=talon-victim,team=workshop \
    --overrides='{"spec":{"containers":[{"name":"talon-victim","image":"nginx:alpine","resources":{"requests":{"cpu":"50m","memory":"32Mi"},"limits":{"cpu":"100m","memory":"64Mi"}}}]}}' \
    >/dev/null 2>&1
then
    allow "talon-victim pod admitted (proper labels + limits)"
    # wait for Ready
    for _ in $(seq 1 12); do
        ph=$(kubectl get pod talon-victim -n apps -o jsonpath='{.status.phase}' 2>/dev/null || true)
        [[ "${ph}" == "Running" ]] && break
        sleep 2
    done
else
    fail "could not create talon-victim pod"
    exit 1
fi

section "Trigger Falco alert — kubectl exec into talon-victim"
narrate kubectl exec -n apps talon-victim -- /bin/sh -c 'echo shell-spawn'
kubectl exec -n apps talon-victim -- /bin/sh -c 'echo shell-spawn' >/dev/null 2>&1 || true
info "Falco fires → Falcosidekick routes to falco-talon:2803 → Talon executes terminate"

section "Wait up to 30s for Talon to terminate the pod"
terminated=0
for i in $(seq 1 15); do
    sleep 2
    if ! kubectl get pod talon-victim -n apps >/dev/null 2>&1; then
        terminated=1
        ok "talon-victim TERMINATED by FalcoTalon (auto-response succeeded after ~$((i*2))s)"
        break
    fi
    ph=$(kubectl get pod talon-victim -n apps -o jsonpath='{.status.phase}' 2>/dev/null || true)
    printf '  t+%ds: pod phase=%s\n' "$((i*2))" "${ph:-?}"
done

if [[ "${terminated}" -eq 0 ]]; then
    warn "talon-victim still present after 30s — check Talon logs:"
    narrate kubectl logs -n security -l app.kubernetes.io/name=falco-talon --tail=20
    kubectl logs -n security -l app.kubernetes.io/name=falco-talon --tail=20 2>&1 | sed 's/^/    /'
    # cleanup so the demo can be rerun
    kubectl delete pod talon-victim -n apps --grace-period=0 --force >/dev/null 2>&1 || true
fi

section "Kubernetes Events from Talon's k8sevents notifier"
narrate kubectl get events -n apps --sort-by=.lastTimestamp '|' tail -5
kubectl get events -n apps --sort-by=.lastTimestamp 2>/dev/null | tail -5 | sed 's/^/    /'

printf '\n'
banner "Phase 3 complete (FalcoTalon end-to-end)"
