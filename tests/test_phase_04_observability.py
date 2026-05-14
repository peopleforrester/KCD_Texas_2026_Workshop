# ABOUTME: Phase 4 test gate — Prometheus stack, OTel, Loki, Promtail, Tempo, dashboards.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_4_DONE only after these pass.

import pytest
from conftest import kubectl_json, all_pods_running

pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_prometheus_pod_running():
    """prometheus-kube-prometheus-stack-prometheus-0 StatefulSet pod Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=prometheus")
    assert ok, f"Prometheus pods not Running: {bad}"


def test_grafana_pod_running():
    """Grafana pod Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=grafana")
    assert ok, f"Grafana pods not Running: {bad}"


def test_prometheus_operator_running():
    """Prometheus Operator pod Running."""
    ok, bad = all_pods_running("monitoring", "app=kube-prometheus-stack-operator")
    assert ok, f"Prometheus operator pods not Running: {bad}"


def test_kube_state_metrics_running():
    """kube-state-metrics pod Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=kube-state-metrics")
    assert ok, f"kube-state-metrics pods not Running: {bad}"


def test_node_exporter_daemonset_ready():
    """node-exporter DaemonSet has at least one Ready Pod per node."""
    data = kubectl_json("get", "ds", "-n", "monitoring", "-l", "app.kubernetes.io/name=prometheus-node-exporter")
    items = data.get("items", [])
    assert items, "no node-exporter DaemonSet"
    ds = items[0]
    desired = ds["status"].get("desiredNumberScheduled", 0)
    ready = ds["status"].get("numberReady", 0)
    assert ready >= desired and desired >= 1, f"node-exporter not ready: {ready}/{desired}"


def test_servicemonitors_present():
    """ServiceMonitors include the 3 ArgoCD scrape targets + chart defaults."""
    data = kubectl_json("get", "servicemonitors", "-A")
    names = {item["metadata"]["name"] for item in data.get("items", [])}
    # ArgoCD scrape targets from gitops/manifests/argocd-servicemonitors/
    required = {"argocd-server", "argocd-application-controller", "argocd-repo-server"}
    missing = required - names
    assert not missing, f"Missing ArgoCD ServiceMonitors: {missing}"


def test_otel_collector_pods_running():
    """OpenTelemetry Collector DaemonSet pods Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=opentelemetry-collector")
    assert ok, f"OTel collector pods not Running: {bad}"


def test_loki_pod_running():
    """Loki pod Running (single replica for workshop)."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=loki")
    assert ok, f"Loki pods not Running: {bad}"


def test_tempo_pod_running():
    """Tempo pod Running."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=tempo")
    assert ok, f"Tempo pods not Running: {bad}"


def test_promtail_daemonset_ready():
    """Promtail DaemonSet pods Running on every node."""
    ok, bad = all_pods_running("monitoring", "app.kubernetes.io/name=promtail")
    assert ok, f"Promtail pods not Running: {bad}"
