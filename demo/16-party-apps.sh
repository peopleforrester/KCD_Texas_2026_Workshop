#!/usr/bin/env bash
# ABOUTME: Phase 5 demo — 5 themed party apps (hedgehog, unicorn, spider, wombat, mantis-shrimp).
# ABOUTME: Each is an nginx serving a themed HTML5 Canvas ConfigMap. Show all 5 Running + a port-forward.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 5 — Party apps (5 themed workloads)"
context_card
require_cmd kubectl
require_ns apps || exit 1

PARTY_APPS=(hedgehog-party unicorn-party spider-party wombat-party mantis-shrimp-party)
TEAMS=(zoology fantasy arachnids marsupials crustaceans)

section "All 5 party app deployments"
run kubectl get deploy -n apps -l 'app in (hedgehog-party,unicorn-party,spider-party,wombat-party,mantis-shrimp-party)'

section "Per-app status"
for i in "${!PARTY_APPS[@]}"; do
    app="${PARTY_APPS[$i]}"
    team="${TEAMS[$i]}"
    total=$(pods_total apps "app=${app}")
    running=$(pods_running apps "app=${app}")
    if [[ "${running}" -ge 1 && "${running}" -eq "${total}" ]]; then
        ok "${app} (team=${team}): ${running}/${total} Running"
    else
        fail "${app} (team=${team}): ${running}/${total} Running"
    fi
done

section "HTML ConfigMaps mounted"
for app in hedgehog-party spider-party wombat-party mantis-shrimp-party; do
    if kubectl get cm -n apps "${app}-html" >/dev/null 2>&1; then
        keys=$(kubectl get cm -n apps "${app}-html" -o jsonpath='{.data}' | python3 -c "import json,sys; print(','.join(json.load(sys.stdin).keys()))" 2>/dev/null)
        ok "${app}-html ConfigMap: keys = ${keys}"
    else
        warn "${app}-html ConfigMap missing — pod will serve default nginx welcome page"
    fi
done
info "unicorn-party intentionally has no HTML ConfigMap (default nginx page)"

section "Backstage catalog entries (each party = a Component)"
narrate kubectl get cm -n backstage backstage-catalog -o jsonpath='{.data}' '|' grep -c party
catalog_data=$(kubectl get cm -n backstage backstage-catalog -o jsonpath='{.data}' 2>/dev/null || echo '')
party_refs=$(echo "${catalog_data}" | grep -c party 2>/dev/null || echo 0)
if [[ "${party_refs}" -gt 0 ]]; then
    ok "Backstage catalog references party apps (${party_refs} mentions)"
else
    warn "no party app references found in Backstage catalog ConfigMap"
fi

section "View one in a browser"
info "Pick any party to demo:"
for app in "${PARTY_APPS[@]}"; do
    printf "    "
    narrate kubectl port-forward -n apps svc/"${app}" 8088:80
done
echo
echo "  Then browse: http://localhost:8088"

printf '\n'
banner "Party apps verified — 5/5 themed Components in the platform"
