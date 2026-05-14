# ABOUTME: Phase 5 test gate — Backstage portal + catalog + templates.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_5_DONE only after these pass.

import pytest
import subprocess
from conftest import kubectl_json, all_pods_running

pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_backstage_pod_running():
    """Backstage Pod must be Running — the no-default-image trap fires here if missed."""
    ok, bad = all_pods_running("backstage", "app.kubernetes.io/name=backstage")
    if not ok:
        try:
            logs = subprocess.run(
                ["kubectl", "logs", "-n", "backstage",
                 "-l", "app.kubernetes.io/name=backstage", "--tail=50"],
                capture_output=True, text=True, timeout=15,
            )
            log_excerpt = logs.stdout[-2000:] if logs.stdout else "(no logs)"
        except Exception:
            log_excerpt = "(could not fetch logs)"
        pytest.fail(f"Backstage Pod not Running: {bad}\nRecent logs:\n{log_excerpt}")


def test_backstage_service_has_endpoints():
    """The backstage Service has at least one Ready endpoint on port 7007."""
    data = kubectl_json("get", "endpoints", "backstage", "-n", "backstage")
    subsets = data.get("subsets", [])
    addresses = [a for s in subsets for a in s.get("addresses", [])]
    assert addresses, "backstage Service has no ready endpoints"
    ports = {p["port"] for s in subsets for p in s.get("ports", [])}
    assert 7007 in ports, f"Backstage Service ports {ports} do not include 7007"


def test_backstage_image_is_pinned():
    """Workshop pin: ghcr.io/backstage/backstage:1.30.2 (no default image trap)."""
    data = kubectl_json("get", "deployment", "backstage", "-n", "backstage")
    containers = data["spec"]["template"]["spec"]["containers"]
    images = [c["image"] for c in containers]
    expected = "ghcr.io/backstage/backstage:1.30.2"
    assert expected in images, f"Backstage image not pinned to {expected}. Got: {images}"


def test_argocd_application_healthy():
    """backstage Application Synced + Healthy."""
    data = kubectl_json("get", "application", "backstage", "-n", "argocd")
    sync = data["status"]["sync"]["status"]
    health = data["status"]["health"]["status"]
    assert sync == "Synced" and health == "Healthy", \
        f"backstage not Synced+Healthy: sync={sync}, health={health}"
