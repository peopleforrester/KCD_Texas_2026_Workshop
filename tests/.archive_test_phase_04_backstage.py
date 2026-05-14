# ABOUTME: Phase 4 test gate — Backstage developer portal.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_4_DONE only after these pass.

import pytest
import subprocess
from conftest import kubectl, kubectl_json, all_pods_running


pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_backstage_pod_running():
    """The Backstage Pod must be Running. The no-default-image trap fires here if missed."""
    ok, bad = all_pods_running("backstage", "app.kubernetes.io/name=backstage")
    if not ok:
        # Pull logs to surface why — this is the talk-payoff moment
        try:
            logs = subprocess.run(
                ["kubectl", "logs", "-n", "backstage",
                 "-l", "app.kubernetes.io/name=backstage", "--tail=50"],
                capture_output=True, text=True, timeout=15,
            )
            log_excerpt = logs.stdout[-2000:] if logs.stdout else "(no logs)"
        except Exception:
            log_excerpt = "(could not fetch logs)"
        pytest.fail(
            f"Backstage Pod not Running: {bad}\n"
            f"Recent logs:\n{log_excerpt}"
        )


def test_backstage_service_has_endpoints():
    """The backstage Service must have at least one Ready endpoint on port 7007."""
    data = kubectl_json("get", "endpoints", "backstage", "-n", "backstage")
    subsets = data.get("subsets", [])
    addresses = [a for s in subsets for a in s.get("addresses", [])]
    assert len(addresses) >= 1, "backstage Service has no ready endpoints"
    # Confirm port 7007 is in the subsets
    ports = {p["port"] for s in subsets for p in s.get("ports", [])}
    assert 7007 in ports, f"Backstage Service ports {ports} do not include 7007"


def test_backstage_image_is_pinned():
    """The Pod's image must be ghcr.io/backstage/backstage:1.30.2 — the chart has no
    default image; this pin is what stops the Pod from CrashLoopBackOff at start.
    The earlier roadiehq/community-backstage-image:1.50.4 reference doesn't exist
    anywhere (HTTP 404 on GHCR; Docker Hub repo abandoned since 2021-08-07)."""
    data = kubectl_json("get", "deployment", "backstage", "-n", "backstage")
    containers = data["spec"]["template"]["spec"]["containers"]
    images = [c["image"] for c in containers]
    expected = "ghcr.io/backstage/backstage:1.30.2"
    assert expected in images, \
        f"Backstage image not pinned to {expected}. Got: {images}"


def test_argocd_application_healthy():
    """The backstage Application reports Healthy AND Synced."""
    data = kubectl_json("get", "application", "backstage", "-n", "argocd")
    sync = data["status"]["sync"]["status"]
    health = data["status"]["health"]["status"]
    assert sync == "Synced" and health == "Healthy", \
        f"backstage Application not Synced+Healthy: sync={sync}, health={health}"
