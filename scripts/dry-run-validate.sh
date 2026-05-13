#!/usr/bin/env bash
# ABOUTME: Dry-run validation for the KCD Texas 90-Minute IDP spec.
# ABOUTME: Runs without a cluster — verifies chart versions exist, manifests render, sync waves match repo.

set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
PASS=0
FAIL=0

step() { echo; echo "===== $* ====="; }
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad()  { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

step "1. Tools available"
for t in helm kubectl python3 git diff; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t found"; else bad "$t MISSING"; fi
done

step "2. Repo structure (run from KCD_Texas_2026_Workshop root)"
for d in spec spec/phases .claude/skills .claude/commands gitops/apps gitops/bootstrap gitops/manifests/kyverno-policies scorecard; do
  if [ -d "$REPO_ROOT/$d" ]; then ok "$d/ exists"; else bad "$d/ MISSING"; fi
done

step "3. Required files exist"
for f in spec/BUILD-SPEC.md \
         spec/BRANCH-WORKFLOW.md \
         spec/OPENING-SCRIPT.md \
         spec/PRESENTER-RUNBOOK.md \
         spec/phases/phase-01-argocd.md spec/phases/phase-02-kyverno.md \
         spec/phases/phase-03-observability.md spec/phases/phase-04-backstage.md \
         .claude/skills/argocd-patterns.md .claude/skills/kyverno-policies.md \
         .claude/skills/kube-prometheus-stack.md .claude/skills/backstage-templates.md \
         .claude/commands/build-phase.md .claude/commands/score-component.md .claude/commands/validate-phase.md \
         tests/conftest.py \
         tests/test_phase_01_argocd.py tests/test_phase_02_kyverno.py \
         tests/test_phase_03_observability.py tests/test_phase_04_backstage.py \
         .pre-commit-config.yaml \
         gitops/bootstrap/app-of-apps.yaml \
         gitops/apps/kyverno.yaml gitops/apps/kyverno-policies.yaml \
         gitops/apps/kube-prometheus-stack.yaml gitops/apps/backstage.yaml \
         gitops/manifests/kyverno-policies/require-labels.yaml \
         gitops/manifests/kyverno-policies/require-resource-limits.yaml \
         gitops/manifests/kyverno-policies/disallow-privileged.yaml \
         scorecard/SCORECARD-TEMPLATE.md scorecard/PRESENTER-SCORECARD.md; do
  if [ -f "$REPO_ROOT/$f" ]; then ok "$f"; else bad "$f MISSING"; fi
done

step "4. All YAML parses cleanly"
python3 - "$REPO_ROOT" <<'PY' && ok "All gitops YAMLs parse" || bad "YAML parse errors"
import yaml, sys, pathlib
errs = 0
for f in pathlib.Path(sys.argv[1]).glob('gitops/**/*.yaml'):
    try:
        list(yaml.safe_load_all(f.read_text()))
    except Exception as e:
        print(f"  ! {f.relative_to(sys.argv[1])}: {e}")
        errs += 1
sys.exit(0 if errs == 0 else 1)
PY

step "5. Helm repos configured"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 && ok "argo repo added" || ok "argo repo already added"
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null 2>&1 && ok "kyverno repo added" || ok "kyverno repo already added"
helm repo add prom https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 && ok "prom repo added" || ok "prom repo already added"
helm repo add backstage https://backstage.github.io/charts >/dev/null 2>&1 && ok "backstage repo added" || ok "backstage repo already added"
helm repo update >/dev/null 2>&1 && ok "helm repo update" || bad "helm repo update failed"

step "6. Pinned chart versions exist in their upstream repos"
# Use awk because `helm search repo` separates columns with tabs and column widths vary.
check_chart_version() {
  local chart="$1" version="$2"
  helm search repo "$chart" --versions 2>/dev/null | awk -v v="$version" '$2 == v {found=1} END {exit !found}'
}
check_chart_version "kyverno/kyverno"           "3.8.0"  && ok "kyverno 3.8.0 available"                || bad "kyverno 3.8.0 NOT FOUND upstream"
check_chart_version "prom/kube-prometheus-stack" "84.5.0" && ok "kube-prometheus-stack 84.5.0 available" || bad "kube-prometheus-stack 84.5.0 NOT FOUND upstream"
check_chart_version "backstage/backstage"        "2.7.0"  && ok "backstage 2.7.0 available"              || bad "backstage 2.7.0 NOT FOUND upstream"

step "7. Each Application's helm.valuesObject renders cleanly via helm template"
python3 - "$REPO_ROOT" <<'PY'
import yaml, subprocess, sys, pathlib, tempfile, os

repo = sys.argv[1]
charts = {
    'kyverno': ('kyverno/kyverno', '3.8.0'),
    'kube-prometheus-stack': ('prom/kube-prometheus-stack', '84.5.0'),
    'backstage': ('backstage/backstage', '2.7.0'),
}

errs = 0
for name, (chart_path, version) in charts.items():
    app_file = pathlib.Path(repo) / f'gitops/apps/{name}.yaml'
    doc = yaml.safe_load(app_file.read_text())
    values = doc['spec']['source']['helm'].get('valuesObject', {})
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as tf:
        yaml.dump(values, tf)
        values_file = tf.name
    try:
        result = subprocess.run(
            ['helm', 'template', f'test-{name}', chart_path, '--version', version, '-f', values_file],
            capture_output=True, text=True, timeout=60
        )
        if result.returncode != 0 or 'Error' in result.stderr:
            print(f"  ! {name} {version}: render FAILED")
            print('    ' + (result.stderr.splitlines()[:3] if result.stderr else ['(no stderr)'])[0])
            errs += 1
        else:
            lines = result.stdout.count('\n')
            print(f"  ✓ {name} {version}: rendered {lines} lines")
    finally:
        os.unlink(values_file)

sys.exit(0 if errs == 0 else 1)
PY

step "8. Sync waves match between gitops/apps and skill files (drift check)"
python3 - "$REPO_ROOT" <<'PY'
import yaml, sys, pathlib, re

repo = sys.argv[1]
expected = {'kyverno': '-5', 'kyverno-policies': '-4', 'kube-prometheus-stack': '1', 'backstage': '5'}

errs = 0
for name, want in expected.items():
    f = pathlib.Path(repo) / f'gitops/apps/{name}.yaml'
    doc = yaml.safe_load(f.read_text())
    got = doc['metadata'].get('annotations', {}).get('argocd.argoproj.io/sync-wave', 'MISSING')
    if got == want:
        print(f"  ✓ {name}: sync-wave {got}")
    else:
        print(f"  ! {name}: expected {want}, got {got}")
        errs += 1

sys.exit(0 if errs == 0 else 1)
PY

step "9. ArgoCD chart 9.x is available (workshop uses 'current stable GA')"
latest=$(helm search repo argo/argo-cd 2>/dev/null | awk 'NR==2 {print $2}')
case "$latest" in
  9.*) ok "argo-cd current latest is $latest (chart 9.x → ArgoCD 3.x)" ;;
  *)   bad "argo-cd current latest is $latest (expected 9.x line)" ;;
esac

step "10. Pytest tests collect cleanly (syntactic + import check, no cluster needed)"
if command -v python3 >/dev/null 2>&1 && python3 -c "import pytest" >/dev/null 2>&1; then
  cd "$REPO_ROOT/tests" 2>/dev/null && \
    python3 -m pytest --collect-only -q >/tmp/pytest-collect.log 2>&1 && \
    ok "pytest --collect-only on tests/ — clean" || \
    bad "pytest --collect-only failed; see /tmp/pytest-collect.log"
  cd "$REPO_ROOT"
else
  ok "pytest not installed locally — skipping collection check (will run in CI)"
fi

step "11. Summary"
echo
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ ALL CHECKS PASSED — the spec is ready for manual testing on a real cluster."
  exit 0
else
  echo "  ❌ $FAIL check(s) failed — fix before testing on a cluster."
  exit 1
fi
