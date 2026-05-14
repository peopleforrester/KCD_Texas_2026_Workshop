#!/usr/bin/env bash
# ABOUTME: Phase 5 demo — 3 ecom apps (ecom-api, ecom-frontend, ecom-worker).
# ABOUTME: Demonstrates a multi-service team's apps deployed via the platform.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 5 — Ecom apps (multi-service team)"
context_card
require_cmd kubectl
require_ns apps || exit 1

section "All 3 ecom deployments + services"
run kubectl get deploy -n apps -l 'app in (ecom-api,ecom-frontend,ecom-worker)'
run kubectl get svc -n apps -l 'app in (ecom-api,ecom-frontend,ecom-worker)'

section "Per-app status"
for app in ecom-api ecom-frontend ecom-worker; do
    total=$(pods_total apps "app=${app}")
    running=$(pods_running apps "app=${app}")
    if [[ "${running}" -ge 1 && "${running}" -eq "${total}" ]]; then
        ok "${app}: ${running}/${total} Running (team=ecommerce)"
    else
        fail "${app}: ${running}/${total} Running"
    fi
done

section "OTel env injection — confirm trace export endpoint"
for app in ecom-api ecom-worker; do
    endpoint=$(kubectl get deploy "${app}" -n apps \
        -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}' 2>/dev/null)
    if [[ -n "${endpoint}" ]]; then
        ok "${app}: OTEL_EXPORTER_OTLP_ENDPOINT=${endpoint}"
    else
        warn "${app}: no OTEL_EXPORTER_OTLP_ENDPOINT env (substitute nginx; not real Python/Node ecom)"
    fi
done

section "View ecom-frontend in a browser"
narrate kubectl port-forward -n apps svc/ecom-frontend 8087:80
echo "  Then browse: http://localhost:8087"

printf '\n'
banner "Ecom apps verified — 3/3 ecommerce-team workloads"
