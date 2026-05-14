#!/usr/bin/env bash
# ABOUTME: Phase 4 demo — Loki + Promtail (logs) and Tempo (traces).
# ABOUTME: Pods Running; documents how to query each from Grafana.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 4 — Loki + Promtail + Tempo (LGTM stack)"
context_card
require_cmd kubectl
require_ns monitoring || exit 1

section "Loki — log aggregation"
run kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
total=$(pods_total monitoring app.kubernetes.io/name=loki)
running=$(pods_running monitoring app.kubernetes.io/name=loki)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} Loki pods Running"
else
    fail "${running}/${total} Loki pods Running (PVC issue? check describe pod)"
fi

section "Promtail — log shipper DaemonSet on every node"
run kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
total=$(pods_total monitoring app.kubernetes.io/name=promtail)
running=$(pods_running monitoring app.kubernetes.io/name=promtail)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} Promtail pods Running"
else
    fail "${running}/${total} Promtail pods Running"
fi

section "Tempo — distributed tracing backend"
run kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo
total=$(pods_total monitoring app.kubernetes.io/name=tempo)
running=$(pods_running monitoring app.kubernetes.io/name=tempo)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} Tempo pods Running"
else
    fail "${running}/${total} Tempo pods Running"
fi

section "Live query: Loki for sample-app logs"
info "Port-forward Loki and run a LogQL query:"
narrate kubectl port-forward -n monitoring svc/loki 3100:3100
echo "  Then:"
echo "    curl -s 'http://localhost:3100/loki/api/v1/query?query={namespace=\"apps\",app=\"sample-app\"}' | jq '.data.result | length'"
echo "  Expected: positive integer = lines being ingested from sample-app via Promtail"

section "Live query: Tempo for sample-app traces"
info "Port-forward Tempo:"
narrate kubectl port-forward -n monitoring svc/tempo 3200:3200
echo "  Then in Grafana → Explore → Tempo datasource → search service.name=sample-app"

section "Or: skip directly to Grafana (everything's a datasource)"
narrate kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
echo "  Browse: http://localhost:3000  (admin / kcd-texas)"
echo "  Explore → switch datasource between Prometheus / Loki / Tempo"

printf '\n'
banner "Phase 4 complete (Loki + Tempo + Promtail)"
