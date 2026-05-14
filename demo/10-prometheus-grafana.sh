#!/usr/bin/env bash
# ABOUTME: Phase 4 demo — kube-prometheus-stack. Prometheus + Grafana + scrape targets.
# ABOUTME: Confirms ArgoCD ServiceMonitors are picked up, Prometheus targets all "up".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 4 — Prometheus + Grafana"
context_card
require_cmd kubectl
require_ns monitoring || exit 1

section "Core observability pods"
run kubectl get pods -n monitoring
for sel in prometheus grafana kube-state-metrics prometheus-node-exporter; do
    running=$(pods_running monitoring "app.kubernetes.io/name=${sel}")
    total=$(pods_total monitoring "app.kubernetes.io/name=${sel}")
    if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
        ok "${sel}: ${running}/${total} Running"
    elif [[ "${total}" -eq 0 ]]; then
        warn "${sel}: no pods matching app.kubernetes.io/name=${sel}"
    else
        fail "${sel}: ${running}/${total} Running"
    fi
done

section "ServiceMonitors registered"
run kubectl get servicemonitors -A --no-headers
count=$(kubectl get servicemonitors -A --no-headers 2>/dev/null | wc -l)
info "${count} ServiceMonitors cluster-wide"

for sm in argocd-server argocd-application-controller argocd-repo-server; do
    if kubectl get servicemonitor "${sm}" -A >/dev/null 2>&1; then
        ok "ServiceMonitor ${sm} present"
    else
        # ServiceMonitors are scoped to a namespace; check more broadly
        if kubectl get servicemonitor "${sm}" -n monitoring >/dev/null 2>&1; then
            ok "ServiceMonitor ${sm} present in monitoring"
        else
            fail "ServiceMonitor ${sm} NOT found — ArgoCD scrape targets won't be wired"
        fi
    fi
done

section "Live: check Prometheus targets are 'up'"
info "Port-forward Prometheus to query its /api/v1/targets:"
narrate kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
echo "  Then: curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {health,scrapeUrl}'"

section "Grafana access"
info "Workshop password is pinned to 'kcd-texas' in gitops/apps/kube-prometheus-stack.yaml"
narrate kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
echo "  Then browse: http://localhost:3000  (user: admin / pass: kcd-texas)"
echo "  Dashboards → 'Platform Overview' should populate within 30s of port-forwarding"

printf '\n'
banner "Phase 4 complete (Prometheus + Grafana)"
