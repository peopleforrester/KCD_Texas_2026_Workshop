#!/usr/bin/env bash
# ABOUTME: Phase 5 demo — Backstage developer portal. Pod, Service, catalog API, port-forward.
# ABOUTME: Accepts 200 or 401 from /api/catalog/entities (auth-gated is fine — API up).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 5 — Backstage developer portal"
context_card
require_cmd kubectl
require_ns backstage || exit 1

section "Backstage Pod Running (the no-default-image trap)"
run kubectl get pods -n backstage -l app.kubernetes.io/name=backstage
total=$(pods_total backstage app.kubernetes.io/name=backstage)
running=$(pods_running backstage app.kubernetes.io/name=backstage)
if [[ "${running}" -eq "${total}" && "${total}" -ge 1 ]]; then
    ok "${running}/${total} Backstage pods Running"
else
    fail "${running}/${total} Backstage pods Running"
    info "If CrashLoopBackOff, check: kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=80"
    info "Common causes: missing image config OR missing appConfig.kubernetes override"
fi

section "Image pinned to ghcr.io/backstage/backstage:1.30.2"
img=$(kubectl get deploy backstage -n backstage -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo '')
if [[ "${img}" == "ghcr.io/backstage/backstage:1.30.2" ]]; then
    ok "image: ${img}"
else
    warn "image is ${img} (workshop expects ghcr.io/backstage/backstage:1.30.2)"
fi

section "Service has endpoints on port 7007"
data=$(kubectl get endpoints backstage -n backstage -o json 2>/dev/null || echo '{}')
eps=$(echo "${data}" | python3 -c "import json,sys; d=json.load(sys.stdin); s=d.get('subsets',[]); print(len([a for x in s for a in x.get('addresses',[])]))" 2>/dev/null || echo 0)
if [[ "${eps}" -ge 1 ]]; then
    ok "Service has ${eps} ready endpoint(s)"
else
    fail "Service has no ready endpoints"
fi

section "Live: catalog API via in-cluster port-forward"
narrate kubectl port-forward -n backstage svc/backstage 7007:7007 '&'
(
    nohup kubectl port-forward -n backstage svc/backstage 7077:7007 >/tmp/bs-pf.log 2>&1 &
    PFPID=$!
    sleep 4
    status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:7077/.backstage/health/v1/liveness 2>/dev/null || echo "000")
    if [[ "${status}" == "200" ]]; then
        ok "liveness probe: HTTP 200"
    else
        fail "liveness probe: HTTP ${status}"
    fi

    status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:7077/api/catalog/entities 2>/dev/null || echo "000")
    case "${status}" in
        200|301|302) allow "catalog API: HTTP ${status} (entities accessible)" ;;
        401|403) allow "catalog API: HTTP ${status} (auth-gated; API is reachable)" ;;
        000) fail "catalog API unreachable (port-forward issue?)" ;;
        *) fail "catalog API: HTTP ${status} (unexpected)" ;;
    esac

    kill "${PFPID}" 2>/dev/null
    wait 2>/dev/null
) 2>&1

section "Browser access for the projector"
narrate kubectl port-forward -n backstage svc/backstage 7007:7007
echo "  Then browse: http://localhost:7007"
echo "  Catalog → workshop demo apps should be listed (sample-app, party apps, ecom)"

printf '\n'
banner "Phase 5 complete (Backstage)"
