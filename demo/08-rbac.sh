#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — RBAC. Workshop ClusterRoles + RoleBindings present; access checks.
# ABOUTME: Uses kubectl auth can-i to demonstrate scoped permissions vs cluster-admin reach.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — RBAC"
context_card
require_cmd kubectl

section "ClusterRoles defined"
run kubectl get clusterroles -l app.kubernetes.io/part-of=kubeauto-idp
count=$(kubectl get clusterroles -l app.kubernetes.io/part-of=kubeauto-idp --no-headers 2>/dev/null | wc -l)
if [[ "${count}" -ge 1 ]]; then
    ok "${count} workshop ClusterRoles found"
else
    warn "no labeled workshop ClusterRoles — checking unlabeled count"
    total=$(kubectl get clusterroles --no-headers 2>/dev/null | wc -l)
    info "cluster has ${total} ClusterRoles total (most are built-in)"
fi

section "RoleBindings"
run kubectl get rolebindings -A --no-headers
count=$(kubectl get rolebindings -A --no-headers 2>/dev/null | wc -l)
ok "${count} RoleBindings cluster-wide"

section "Current user's permissions — kubectl auth can-i"
narrate kubectl auth can-i '*' '*'
if can=$(kubectl auth can-i '*' '*' 2>/dev/null); then
    if [[ "${can}" == "yes" ]]; then
        allow "current identity has cluster-admin scope ('*' on '*')"
        info "this is correct for instructor or attendee-admin; a real app SA should be DENIED"
    else
        deny "current identity does not have cluster-admin"
    fi
fi

section "Test: can a default-namespace SA list secrets in platform?"
narrate kubectl auth can-i list secrets --as=system:serviceaccount:default:default -n platform
result=$(kubectl auth can-i list secrets \
    --as=system:serviceaccount:default:default -n platform 2>/dev/null || echo "no")
if [[ "${result}" == "no" ]]; then
    deny "default SA cannot list secrets in platform (good — RBAC scoping works)"
else
    fail "default SA CAN list secrets in platform — RBAC scope is too broad"
fi

section "Test: can a default-namespace SA create pods in kube-system?"
narrate kubectl auth can-i create pods --as=system:serviceaccount:default:default -n kube-system
result=$(kubectl auth can-i create pods \
    --as=system:serviceaccount:default:default -n kube-system 2>/dev/null || echo "no")
if [[ "${result}" == "no" ]]; then
    deny "default SA cannot create pods in kube-system (good — system NS protected)"
else
    fail "default SA CAN create pods in kube-system — investigate RBAC"
fi

printf '\n'
banner "Phase 3 complete (RBAC)"
