#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — NetworkPolicies. Default-deny + per-namespace allows.
# ABOUTME: Lists policies; runs a real cross-namespace egress test from apps namespace.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — NetworkPolicies"
context_card
require_cmd kubectl
require_ns apps || exit 1

section "NetworkPolicies in apps namespace"
run kubectl get networkpolicies -n apps
count=$(kubectl get networkpolicies -n apps --no-headers 2>/dev/null | wc -l)
if [[ "${count}" -ge 1 ]]; then
    ok "${count} NetworkPolicies enforcing in apps namespace"
else
    fail "no NetworkPolicies in apps — default-deny isn't configured"
fi

section "NetworkPolicies cluster-wide"
run kubectl get networkpolicies -A --no-headers

section "Live egress test: from apps pod, can we reach kube-system DNS?"
pod=$(kubectl get pods -n apps -l app=sample-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "${pod}" ]]; then
    pod=$(kubectl get pods -n apps -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi

if [[ -z "${pod}" ]]; then
    warn "no apps pod to test from; skipping live egress test"
else
    info "test source: ${pod}"
    section "Allowed egress: DNS to kube-system on UDP 53 (must succeed)"
    narrate kubectl exec -n apps "${pod}" -- timeout 3 nslookup kubernetes.default
    if kubectl exec -n apps "${pod}" -- timeout 3 nslookup kubernetes.default >/dev/null 2>&1; then
        allow "DNS lookup succeeded (per-namespace allow rule lets DNS through)"
    else
        warn "DNS lookup failed — NetworkPolicy may be too restrictive OR image lacks nslookup"
    fi

    section "Denied egress: arbitrary external host (workshop policy blocks general egress)"
    narrate kubectl exec -n apps "${pod}" -- timeout 3 wget -qO- http://example.com
    if kubectl exec -n apps "${pod}" -- timeout 3 wget -qO- http://example.com >/dev/null 2>&1; then
        warn "external HTTP succeeded — NetworkPolicy may not block egress here"
        info "(some workshop default-allow configs permit egress; check default-deny.yaml)"
    else
        deny "external HTTP blocked (NetworkPolicy default-deny working)"
    fi
fi

printf '\n'
banner "Phase 3 complete (NetworkPolicies)"
