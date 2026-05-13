# ABOUTME: Phase 3 test gate — kube-prometheus-stack (Prometheus + Grafana).
# ABOUTME: All tests hit real infrastructure. Promise PHASE_3_DONE only after these pass.

import pytest
from conftest import kubectl, kubectl_json, all_pods_running


pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_prometheus_pod_running():
    """Prometheus StatefulSet pod must be Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=prometheus")
    assert ok, f"Prometheus pods not Running: {bad}"


def test_grafana_pod_running():
    """Grafana Deployment pod must be Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=grafana")
    assert ok, f"Grafana pods not Running: {bad}"


def test_operator_pod_running():
    """The Prometheus operator itself must be Running."""
    ok, bad = all_pods_running("monitoring", "app=kube-prometheus-stack-operator")
    assert ok, f"Prometheus operator pods not Running: {bad}"


def test_kube_state_metrics_running():
    """kube-state-metrics must be Running (key data source for default dashboards)."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=kube-state-metrics")
    assert ok, f"kube-state-metrics not Running: {bad}"


def test_node_exporter_daemonset_ready():
    """node-exporter DaemonSet must be fully scheduled (one pod per node, all Ready)."""
    data = kubectl_json("get", "daemonset",
                        "-n", "monitoring",
                        "-l", "app.kubernetes.io/name=prometheus-node-exporter")
    items = data["items"]
    assert items, "node-exporter DaemonSet not found"
    ds = items[0]["status"]
    desired = ds.get("desiredNumberScheduled", 0)
    ready = ds.get("numberReady", 0)
    assert desired > 0 and desired == ready, \
        f"node-exporter not fully Ready: {ready}/{desired}"


def test_servicemonitors_auto_created():
    """Chart should auto-create ~10 ServiceMonitors. Verify at least 5 exist."""
    data = kubectl_json("get", "servicemonitors", "-n", "monitoring")
    count = len(data["items"])
    assert count >= 5, f"Only {count} ServiceMonitors found, expected >= 5"


def test_argocd_application_healthy():
    """The kube-prometheus-stack Application reports Healthy AND Synced."""
    data = kubectl_json("get", "application", "kube-prometheus-stack", "-n", "argocd")
    sync = data["status"]["sync"]["status"]
    health = data["status"]["health"]["status"]
    assert sync == "Synced" and health == "Healthy", \
        f"kube-prometheus-stack Application not Synced+Healthy: sync={sync}, health={health}"
