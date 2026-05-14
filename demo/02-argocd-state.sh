#!/usr/bin/env bash
# ABOUTME: Phase 2 demo — verify ArgoCD bootstrap + app-of-apps + all child Applications.
# ABOUTME: Surfaces Sync + Health per Application; flags any Degraded explicitly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 2 — ArgoCD + app-of-apps"
context_card
require_cmd kubectl
require_ns argocd || exit 1

section "ArgoCD core pods"
run kubectl get pods -n argocd
total=$(pods_total argocd)
running=$(pods_running argocd)
if [[ "${running}" -eq "${total}" && "${total}" -ge 6 ]]; then
    ok "${running}/${total} ArgoCD pods Running"
else
    fail "${running}/${total} ArgoCD pods Running (expected >=6)"
fi

section "app-of-apps + child Applications"
if ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    fail "ArgoCD Application CRD not installed"
    exit 1
fi
run kubectl get application -n argocd
apps_total=$(kubectl get application -n argocd --no-headers 2>/dev/null | wc -l)
apps_healthy=$(kubectl get application -n argocd --no-headers 2>/dev/null | awk '$3=="Healthy"' | wc -l)
apps_degraded=$(kubectl get application -n argocd --no-headers 2>/dev/null | awk '$3=="Degraded"' | wc -l)
apps_synced=$(kubectl get application -n argocd --no-headers 2>/dev/null | awk '$2=="Synced"' | wc -l)

printf '\n'
ok "Applications discovered: ${apps_total}"
info "Healthy: ${apps_healthy} / Synced: ${apps_synced} / Degraded: ${apps_degraded}"

if [[ "${apps_degraded}" -gt 0 ]]; then
    section "Degraded Applications (expected: ESO if no IRSA wired)"
    kubectl get application -n argocd --no-headers 2>/dev/null \
        | awk '$3=="Degraded" {printf "  - %s (sync=%s)\n", $1, $2}'
    warn "Degraded Applications above — check whether expected (ESO=IRSA-gap) or real bug"
fi

section "Phase 2 promise check"
if [[ "${apps_total}" -ge 30 && "${apps_healthy}" -ge 30 ]]; then
    ok "<promise>PHASE_2_DONE</promise>"
else
    fail "Phase 2 incomplete: ${apps_healthy}/${apps_total} Healthy"
fi

section "ArgoCD UI access"
info "To reach the UI:"
narrate kubectl port-forward -n argocd svc/argocd-server 8080:443
narrate kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' '|' base64 -d
echo "  Then browse: http://localhost:8080  (username: admin)"

printf '\n'
banner "Phase 2 complete"
