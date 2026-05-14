#!/usr/bin/env bash
# ABOUTME: Phase 7 demo — cert-manager. Operator pods + ClusterIssuers registered.
# ABOUTME: ClusterIssuers will be Ready=False without DNS (expected workshop variance).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 7 — cert-manager + ClusterIssuers"
context_card
require_cmd kubectl
require_ns cert-manager || exit 1

section "cert-manager operator pods"
run kubectl get pods -n cert-manager
total=$(pods_total cert-manager)
running=$(pods_running cert-manager)
if [[ "${running}" -eq "${total}" && "${total}" -ge 3 ]]; then
    ok "${running}/${total} cert-manager pods Running (cert-manager + cainjector + webhook)"
else
    fail "${running}/${total} cert-manager pods Running (expected 3+)"
fi

section "CRDs installed"
for crd in certificates.cert-manager.io clusterissuers.cert-manager.io issuers.cert-manager.io; do
    if kubectl get crd "${crd}" >/dev/null 2>&1; then
        ok "${crd}"
    else
        fail "${crd} MISSING"
    fi
done

section "ClusterIssuers registered"
if ! kubectl get clusterissuers >/dev/null 2>&1; then
    warn "no ClusterIssuers — cert-manager-issuers Application may not be Synced yet"
else
    run kubectl get clusterissuers
    while IFS= read -r issuer; do
        [[ -z "${issuer}" ]] && continue
        ready=$(kubectl get clusterissuer "${issuer}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [[ "${ready}" == "True" ]]; then
            ok "${issuer} Ready=True"
        else
            warn "${issuer} Ready=${ready:-Unknown} (expected on workshop: no DNS-01 wired)"
        fi
    done < <(kubectl get clusterissuers -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n')
fi

section "Honest scorecard note"
info "  Install:     9-10 (operator + CRDs + ClusterIssuers all apply)"
info "  Integration: 4-6  (cannot mint real certs without DNS-01 / HTTP-01)"
info "  Usability:   5-7  (would-be-easy if real DNS wired)"
info "  This is the workshop's 'AI installed, ops still needs DNS' data point."

printf '\n'
banner "Phase 7 complete (cert-manager)"
