# ABOUTME: Phase 1 test gate — pre-provisioned cluster foundation assertions.
# ABOUTME: No deployment in this phase; checks that the Accenture cluster + addons are healthy.

import pytest
from conftest import kubectl_json, all_pods_running

pytestmark = pytest.mark.usefixtures("cluster_reachable")

REQUIRED_NAMESPACES = {
    "argocd", "apps", "kyverno", "monitoring", "backstage",
    "security", "platform", "cert-manager",
    "falco",       # holds FalcoTalon's leader-election Lease; empty by design
    "kube-system",
}


def test_node_count_at_least_two():
    """Workshop expects 3 nodes; minimum 2 to fit the stack."""
    data = kubectl_json("get", "nodes")
    nodes = data.get("items", [])
    assert len(nodes) >= 2, f"Need >=2 nodes, found {len(nodes)}"


def test_all_nodes_ready():
    """Every node must be Ready (no NotReady or unknown)."""
    data = kubectl_json("get", "nodes")
    not_ready = []
    for n in data["items"]:
        name = n["metadata"]["name"]
        conditions = n["status"].get("conditions", [])
        ready = next((c for c in conditions if c.get("type") == "Ready"), None)
        if not ready or ready.get("status") != "True":
            not_ready.append((name, ready.get("status") if ready else "MISSING"))
    assert not not_ready, f"Nodes not Ready: {not_ready}"


def test_required_workshop_namespaces_exist():
    """The 6 workshop-critical namespaces must be pre-created."""
    data = kubectl_json("get", "namespaces")
    names = {item["metadata"]["name"] for item in data["items"]}
    missing = REQUIRED_NAMESPACES - names
    assert not missing, f"Missing workshop namespaces: {missing}"


def test_metrics_server_installed():
    """metrics-server should be installed (kubectl top works) — pre-workshop infra task."""
    data = kubectl_json("get", "deployment", "metrics-server", "-n", "kube-system")
    available = data["status"].get("availableReplicas", 0)
    assert available >= 1, "metrics-server deployment has no available replicas"


def test_kube_system_pods_healthy():
    """kube-system base pods (CoreDNS, kube-proxy, vpc-cni, etc.) all Running."""
    ok, bad = all_pods_running("kube-system")
    assert ok, f"Unhealthy pods in kube-system: {bad}"
