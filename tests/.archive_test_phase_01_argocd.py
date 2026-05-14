# ABOUTME: Phase 1 test gate — ArgoCD bootstrap + app-of-apps.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_1_DONE only after these pass.

import pytest
from conftest import kubectl, kubectl_json, all_pods_running


pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_argocd_core_pods_running():
    """All ArgoCD core controllers should be Running."""
    ok, bad = all_pods_running("argocd")
    assert ok, f"Non-running pods in argocd namespace: {bad}"


def test_argocd_server_responds():
    """The argocd-server Service should have at least one Ready endpoint."""
    data = kubectl_json("get", "endpoints", "argocd-server", "-n", "argocd")
    subsets = data.get("subsets", [])
    addresses = [a for s in subsets for a in s.get("addresses", [])]
    assert len(addresses) >= 1, "argocd-server Service has no ready endpoints"


def test_app_of_apps_exists_and_synced():
    """The bootstrap app-of-apps Application exists and is Synced."""
    data = kubectl_json("get", "application", "app-of-apps", "-n", "argocd")
    sync = data["status"]["sync"]["status"]
    assert sync == "Synced", f"app-of-apps sync status is '{sync}', expected 'Synced'"


def test_app_of_apps_targets_main_branch():
    """Bootstrap must point at main branch — staging is for in-flight work, ArgoCD reads canonical."""
    data = kubectl_json("get", "application", "app-of-apps", "-n", "argocd")
    target = data["spec"]["source"]["targetRevision"]
    assert target == "main", f"app-of-apps targetRevision is '{target}', expected 'main'"


def test_four_children_discovered():
    """ArgoCD discovered the four child Applications under gitops/apps/."""
    data = kubectl_json("get", "applications", "-n", "argocd")
    names = {item["metadata"]["name"] for item in data["items"]}
    required = {"kyverno", "kyverno-policies", "kube-prometheus-stack", "backstage"}
    missing = required - names
    assert not missing, f"app-of-apps did not discover: {missing}"
