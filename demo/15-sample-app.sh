#!/usr/bin/env bash
# ABOUTME: Phase 5 demo — sample-app (Flask + OTel auto-instrumented).
# ABOUTME: Hit /, /health, /ready endpoints directly to show the real app responding.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "sample-app — Flask + OpenTelemetry"
context_card
require_cmd kubectl
require_ns apps || exit 1

section "Pod state"
run kubectl get pods -n apps -l app=sample-app
total=$(pods_total apps app=sample-app)
running=$(pods_running apps app=sample-app)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} sample-app pods Running"
else
    fail "${running}/${total} sample-app pods Running"
fi

section "Image is the published Flask+OTel build"
img=$(kubectl get deploy sample-app -n apps -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo '')
case "${img}" in
    *workshop/sample-app:*) ok "image: ${img} (real Flask + OTel)" ;;
    *nginx*)               warn "image is ${img} — substitute, not the real Flask app" ;;
    "")                    fail "no image in deployment spec" ;;
    *)                     warn "image: ${img}" ;;
esac

section "Hit the Flask endpoints inside the cluster"
pod=$(kubectl get pods -n apps -l app=sample-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo '')
if [[ -z "${pod}" ]]; then
    fail "no sample-app pod found"
    exit 1
fi
info "target pod: ${pod}"

for path in "/" "/health" "/ready"; do
    printf '\n%b── GET %s%b\n' "${_FG_CYN}" "${path}" "${_RST}"
    if resp=$(kubectl exec -n apps "${pod}" -- python3 -c "import urllib.request,sys; sys.stdout.write(urllib.request.urlopen('http://localhost:8080${path}').read().decode())" 2>/dev/null); then
        echo "    ${resp}"
        ok "GET ${path} → 200 OK"
    else
        fail "GET ${path} failed"
    fi
done

section "Service endpoints"
run kubectl get svc sample-app -n apps
eps_ip=$(kubectl get endpoints sample-app -n apps -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo '')
if [[ -n "${eps_ip}" ]]; then
    ok "Service backed by: ${eps_ip}"
else
    fail "Service has no ready endpoints"
fi

section "External access for the projector"
narrate kubectl port-forward -n apps svc/sample-app 7090:80
echo "  Then: curl http://localhost:7090/"
echo "  Or:    open http://localhost:7090/  in a browser"

printf '\n'
banner "sample-app verified"
