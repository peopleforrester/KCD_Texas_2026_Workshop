#!/usr/bin/env bash
# ABOUTME: Phase 3 demo — Kyverno admission control. Bad pod DENIED, good pod ACCESS.
# ABOUTME: Hits the apps namespace where the 3 ClusterPolicies enforce.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

banner "Phase 3 — Kyverno admission control"
context_card
require_cmd kubectl
require_ns kyverno || exit 1
require_ns apps || exit 1

section "Kyverno controllers Running"
run kubectl get pods -n kyverno
total=$(pods_total kyverno)
running=$(pods_running kyverno)
if [[ "${running}" -eq "${total}" ]]; then
    ok "${running}/${total} Kyverno pods Running"
else
    fail "${running}/${total} Kyverno pods Running"
fi

section "3 ClusterPolicies loaded + Enforce mode"
run kubectl get clusterpolicies
for pol in require-labels require-resource-limits disallow-privileged; do
    if kubectl get clusterpolicy "${pol}" >/dev/null 2>&1; then
        action=$(kubectl get clusterpolicy "${pol}" -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
        if [[ "${action}" == "Enforce" ]]; then
            ok "${pol} Ready + Enforce"
        else
            fail "${pol} mode=${action:-MISSING}, expected Enforce"
        fi
    else
        fail "${pol} NOT loaded"
    fi
done

section "Bad pod (no labels, no limits) — should be DENIED"
narrate kubectl run demo-bad --image=nginx -n apps --restart=Never --dry-run=server
if output=$(kubectl run demo-bad --image=nginx -n apps --restart=Never --dry-run=server 2>&1); then
    fail "bad pod ADMITTED — policies aren't enforcing!"
    echo "${output}"
else
    deny "bad pod REJECTED at admission (this is the win)"
    echo "${output}" | sed 's/^/    /' | head -8
fi

section "Good pod (has app+team labels + limits) — should be ACCESS"
narrate kubectl apply --dry-run=server -f /dev/stdin
if kubectl apply --dry-run=server -f - <<'EOF' >/tmp/demo-good.out 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: demo-good
  namespace: apps
  labels:
    app: demo
    team: workshop
spec:
  containers:
    - name: nginx
      image: nginx:alpine
      resources:
        requests: { cpu: "50m", memory: "32Mi" }
        limits:   { cpu: "100m", memory: "64Mi" }
EOF
then
    allow "good pod ADMITTED (policies allowed it)"
    sed 's/^/    /' < /tmp/demo-good.out
else
    fail "good pod REJECTED — investigate, was it really compliant?"
    sed 's/^/    /' < /tmp/demo-good.out
fi
rm -f /tmp/demo-good.out

section "System namespaces unaffected"
sys_total=$(pods_total kube-system)
sys_running=$(pods_running kube-system)
if [[ "${sys_running}" -eq "${sys_total}" ]]; then
    ok "kube-system unaffected (${sys_running}/${sys_total} Running) — webhook scope correct"
else
    fail "${sys_running}/${sys_total} kube-system pods Running — webhook may be over-scoped"
fi

printf '\n'
banner "Phase 3 complete (Kyverno)"
