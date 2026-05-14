#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — External Secrets Operator. Pod healthy; ClusterSecretStore honest gap.
# ABOUTME: ESO Pod is Healthy (Install ✓) but secret store will be Degraded without IRSA wired.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — External Secrets Operator"
context_card
require_cmd kubectl
require_ns platform || exit 1

section "ESO controller + webhook + cert-controller pods"
run kubectl get pods -n platform -l app.kubernetes.io/name=external-secrets
total=$(pods_total platform app.kubernetes.io/name=external-secrets)
running=$(pods_running platform app.kubernetes.io/name=external-secrets)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} ESO pods Running (Install ✓)"
else
    fail "${running}/${total} ESO pods Running"
fi

section "ClusterSecretStore status — the honest gap"
if kubectl get clustersecretstore aws-secrets-manager >/dev/null 2>&1; then
    info "ClusterSecretStore 'aws-secrets-manager' exists"
    run kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions}'
    ready=$(kubectl get clustersecretstore aws-secrets-manager \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [[ "${ready}" == "True" ]]; then
        ok "store Ready — IRSA is wired correctly (rare in workshop context)"
    else
        warn "store NOT Ready (Integration scores low here — expected on Accenture)"
        info "Reason: no IRSA role provisioned for the cluster's OIDC issuer"
        info "This is the workshop's central scorecard variance: AI installed the operator,"
        info "AWS IAM prerequisites stayed unwired. Honest data, not a bug."
    fi
else
    warn "ClusterSecretStore 'aws-secrets-manager' not found (eso-resources Application may not be Synced)"
fi

section "ExternalSecret resources (do any sync to actual K8s Secrets?)"
ext=$(kubectl get externalsecrets -A --no-headers 2>/dev/null | wc -l)
info "ExternalSecret resources cluster-wide: ${ext}"
if [[ "${ext}" -gt 0 ]]; then
    run kubectl get externalsecrets -A
    synced=$(kubectl get externalsecrets -A --no-headers 2>/dev/null | awk '$5=="SecretSynced"' | wc -l)
    if [[ "${synced}" -eq "${ext}" ]]; then
        ok "${synced}/${ext} ExternalSecrets SecretSynced"
    else
        warn "${synced}/${ext} ExternalSecrets SecretSynced (rest stuck on IRSA gap above)"
    fi
fi

section "Score honestly on the live scorecard"
info "  ESO Install:     8-10 (Pods Running, CRDs registered)"
info "  ESO Integration: 2-4  (cannot actually pull secrets without IRSA)"
info "  ESO Usability:   3-5  (UI is just kubectl get externalsecret)"
info "  This Install-Integration gap is the workshop's anchor data point."

printf '\n'
banner "Phase 3 complete (External Secrets — with honest scorecard variance)"
