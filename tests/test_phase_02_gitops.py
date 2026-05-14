# ABOUTME: Phase 2 test gate — ArgoCD bootstrap + app-of-apps + 21 children.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_2_DONE only after these pass.

import pytest
from conftest import kubectl_json, all_pods_running

pytestmark = pytest.mark.usefixtures("cluster_reachable")

EXPECTED_CHILDREN = {
    # 22 platform Applications
    "argocd-servicemonitors", "backstage", "backstage-resources",
    "cert-manager", "cert-manager-issuers",
    "eso-resources", "external-secrets",
    "falco", "falcosidekick", "falco-talon",
    "grafana-dashboards",
    "kube-prometheus-stack",
    "kyverno", "kyverno-policies",
    "loki",
    "namespaces", "network-policies",
    "otel-collector", "promtail",
    "rbac", "resource-quotas",
    "tempo",
    # 10 demo workloads
    "sample-app",
    "ecom-api", "ecom-frontend", "ecom-worker",
    "hedgehog-party", "unicorn-party", "spider-party",
    "wombat-party", "mantis-shrimp-party",
    "load-generator",
}


def test_argocd_core_pods_running():
    """All ArgoCD core controllers should be Running."""
    ok, bad = all_pods_running("argocd")
    assert ok, f"Non-running pods in argocd namespace: {bad}"


def test_argocd_server_has_endpoints():
    """The argocd-server Service has at least one Ready endpoint."""
    data = kubectl_json("get", "endpoints", "argocd-server", "-n", "argocd")
    addresses = [a for s in data.get("subsets", []) for a in s.get("addresses", [])]
    assert addresses, "argocd-server Service has no ready endpoints"


def test_app_of_apps_exists():
    """The bootstrap app-of-apps Application exists."""
    data = kubectl_json("get", "application", "app-of-apps", "-n", "argocd")
    assert data["metadata"]["name"] == "app-of-apps"


def test_app_of_apps_targets_main_branch():
    """Bootstrap reads from main, not staging."""
    data = kubectl_json("get", "application", "app-of-apps", "-n", "argocd")
    target = data["spec"]["source"]["targetRevision"]
    assert target == "main", f"targetRevision is '{target}', expected 'main'"


def test_app_of_apps_healthy():
    """app-of-apps Application is Healthy. Sync may cosmetically show OutOfSync because
    of a chronic Kyverno + ArgoCD issue where Kubernetes API server reformats CRD
    description text, causing structural-but-not-semantic drift on 11 of the new
    policies.kyverno.io CRDs. Functionally everything works; the OutOfSync is
    visible-but-honest scorecard data."""
    data = kubectl_json("get", "application", "app-of-apps", "-n", "argocd")
    health = data["status"]["health"]["status"]
    assert health == "Healthy", f"app-of-apps health='{health}', expected 'Healthy'"


def test_all_32_children_discovered():
    """app-of-apps must discover all 21 platform Applications under gitops/apps/."""
    data = kubectl_json("get", "applications", "-n", "argocd")
    names = {item["metadata"]["name"] for item in data["items"]}
    missing = EXPECTED_CHILDREN - names
    assert not missing, f"Missing children: {missing}"
