#!/usr/bin/env bash
# ABOUTME: Phase 4 demo — OpenTelemetry Collector DaemonSet. OTLP receivers, traces flowing.
# ABOUTME: Verifies the collector is up on every node; documents OTLP endpoint for clients.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 4 — OpenTelemetry Collector"
context_card
require_cmd kubectl
require_ns monitoring || exit 1

section "OTel Collector pods on every node"
run kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
total=$(pods_total monitoring app.kubernetes.io/name=opentelemetry-collector)
running=$(pods_running monitoring app.kubernetes.io/name=opentelemetry-collector)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} OTel Collector pods Running"
else
    fail "${running}/${total} OTel Collector pods Running"
fi

section "DaemonSet desired vs ready"
ds_desired=$(kubectl get ds -n monitoring -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[0].status.desiredNumberScheduled}' 2>/dev/null || echo 0)
ds_ready=$(kubectl get ds -n monitoring -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[0].status.numberReady}' 2>/dev/null || echo 0)
if [[ "${ds_ready}" -ge "${ds_desired}" && "${ds_desired}" -ge 1 ]]; then
    ok "DaemonSet ready on every node (${ds_ready}/${ds_desired})"
else
    fail "DaemonSet ${ds_ready}/${ds_desired} — investigate"
fi

section "Service / endpoints"
run kubectl get svc -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
info "Workshop apps send OTLP traces to: http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317"
info "Workshop apps send OTLP HTTP to:   http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318"

section "Live: trace flow from sample-app"
sa_pod=$(kubectl get pods -n apps -l app=sample-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "${sa_pod}" ]]; then
    ok "sample-app pod ${sa_pod} found — it auto-instruments via OTEL_EXPORTER_OTLP_ENDPOINT env"
    info "Generate a span by hitting any sample-app endpoint:"
    narrate kubectl exec -n apps "${sa_pod}" -- python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/')"
    if kubectl exec -n apps "${sa_pod}" -- python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/')" >/dev/null 2>&1; then
        ok "hit sample-app — trace should appear in Tempo within seconds"
    fi
else
    warn "no sample-app pod found; skip trace-flow demo"
fi

section "Collector logs (look for received OTLP traffic)"
narrate kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=15
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=15 2>/dev/null | sed 's/^/    /' | head -15

printf '\n'
banner "Phase 4 complete (OTel Collector)"
