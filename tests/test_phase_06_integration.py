# ABOUTME: Phase 6 test gate — end-to-end integration across the platform.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_6_DONE only after these pass.

import pytest
import subprocess
import time
from conftest import kubectl, kubectl_json, kubectl_returns_error

pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_argocd_drift_selfheals():
    """Scale argocd-redis to +2, wait up to 3 min, ArgoCD should revert (selfHeal).
    ArgoCD's reconcile cycle in the workshop is 30s; selfHeal kicks in after
    drift detection completes. 3 min allows for slow Helm-chart-managed Apps
    that take a longer reconcile cycle."""
    data = kubectl_json("get", "deployment", "argocd-redis", "-n", "argocd")
    desired = data["spec"]["replicas"]

    kubectl("scale", "deployment", "argocd-redis", "-n", "argocd",
            f"--replicas={desired + 2}")
    reverted = False
    for _ in range(36):  # 36 × 5s = 3 min
        time.sleep(5)
        data = kubectl_json("get", "deployment", "argocd-redis", "-n", "argocd")
        if data["spec"]["replicas"] == desired:
            reverted = True
            break
    if not reverted:
        kubectl("scale", "deployment", "argocd-redis", "-n", "argocd",
                f"--replicas={desired}")
    assert reverted, f"ArgoCD did not selfHeal drift within 180s (still {data['spec']['replicas']} replicas)"


def test_admission_denial_produces_visible_error():
    """Cross-component: Kyverno admission denial returns a clear error message."""
    result = kubectl_returns_error(
        "run", "test-integration-bad", "--image=nginx",
        "-n", "apps", "--restart=Never", "--dry-run=server",
    )
    assert result.returncode != 0
    # The error message includes the policy name + the failed rule
    stderr_lower = result.stderr.lower()
    assert "require-labels" in stderr_lower or "require-resource-limits" in stderr_lower, \
        f"Admission denial missing policy name in stderr: {result.stderr[:300]}"


def test_backstage_catalog_api_reachable():
    """Backstage catalog API reachable via kubectl port-forward; returns parseable JSON.
    Uses the Service abstraction rather than exec-ing into the Pod (the Backstage image
    doesn't ship wget/curl)."""
    import json
    import time as _time
    pod_data = kubectl_json("get", "pods", "-n", "backstage",
                             "-l", "app.kubernetes.io/name=backstage")
    pods = [p for p in pod_data["items"] if p["status"].get("phase") == "Running"]
    assert pods, "no Running Backstage pods to test catalog"

    # Start a port-forward on a unique port to avoid collisions
    pf = subprocess.Popen(
        ["kubectl", "port-forward", "-n", "backstage",
         "svc/backstage", "7077:7007"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    try:
        _time.sleep(4)
        result = subprocess.run(
            ["curl", "-sS", "--max-time", "10",
             "http://localhost:7077/api/catalog/entities"],
            capture_output=True, text=True, timeout=15,
        )
        assert result.returncode == 0, f"curl failed: {result.stderr[:200]}"
        try:
            entities = json.loads(result.stdout)
        except json.JSONDecodeError:
            pytest.fail(f"Catalog returned non-JSON: {result.stdout[:200]}")
        assert isinstance(entities, list), f"Catalog response not a list: {type(entities)}"
        # API reachability is what we gate on; entity count can be 0 (seed catalog)
    finally:
        pf.terminate()
        try:
            pf.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pf.kill()


def test_argocd_total_app_health_status():
    """At least 80% of the 21 child Applications should be Healthy (some may legitimately be Degraded if their prereqs aren't met)."""
    data = kubectl_json("get", "applications", "-n", "argocd")
    apps = [item for item in data["items"]
            if item["metadata"]["name"] != "app-of-apps"]
    healthy = sum(1 for a in apps if a.get("status", {}).get("health", {}).get("status") == "Healthy")
    total = len(apps)
    pct = healthy / total if total else 0
    assert pct >= 0.8, f"Only {healthy}/{total} Applications Healthy ({pct:.0%}). Integration goal: >= 80%"
