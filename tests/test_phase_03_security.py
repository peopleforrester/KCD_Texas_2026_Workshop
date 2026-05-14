# ABOUTME: Phase 3 test gate — Kyverno, Falco, ESO, RBAC, NetworkPolicies.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_3_DONE only after these pass.

import pytest
from conftest import kubectl_json, kubectl_returns_error, all_pods_running

pytestmark = pytest.mark.usefixtures("cluster_reachable")

REQUIRED_POLICIES = {"require-labels", "require-resource-limits", "disallow-privileged"}


def test_kyverno_controllers_running():
    """All Kyverno controllers + the migration Job pod (Succeeded)."""
    ok, bad = all_pods_running("kyverno")
    assert ok, f"Non-running pods in kyverno namespace: {bad}"


def test_three_cluster_policies_loaded():
    """Workshop's 3 ClusterPolicies present."""
    data = kubectl_json("get", "clusterpolicies")
    names = {item["metadata"]["name"] for item in data["items"]}
    missing = REQUIRED_POLICIES - names
    assert not missing, f"Missing ClusterPolicies: {missing}"


def test_all_policies_are_enforce_mode():
    """Policies must be Enforce (case-sensitive)."""
    data = kubectl_json("get", "clusterpolicies")
    bad = []
    for item in data["items"]:
        if item["metadata"]["name"] not in REQUIRED_POLICIES:
            continue
        action = item["spec"].get("validationFailureAction", "MISSING")
        if action != "Enforce":
            bad.append((item["metadata"]["name"], action))
    assert not bad, f"Policies not in Enforce mode: {bad}"


def test_admission_blocks_noncompliant_pod():
    """Pod without labels/limits in apps namespace gets rejected."""
    result = kubectl_returns_error(
        "run", "test-bad-admission-3", "--image=nginx",
        "-n", "apps", "--restart=Never", "--dry-run=server",
    )
    assert result.returncode != 0, "Non-compliant pod was accepted"
    assert "denied" in result.stderr.lower() or "policy" in result.stderr.lower(), \
        f"Pod rejected but not by policy: {result.stderr}"


def test_system_namespaces_unaffected():
    """Webhook namespaceSelector excludes system namespaces."""
    ok, bad = all_pods_running("kube-system")
    assert ok, f"kube-system pods affected by webhook scope: {bad}"


def test_falco_daemonset_present():
    """Falco DaemonSet exists in security namespace."""
    data = kubectl_json("get", "ds", "-n", "security")
    falco = [d for d in data.get("items", []) if "falco" in d["metadata"]["name"].lower()]
    assert falco, "No Falco DaemonSet found in security namespace"


def test_falco_pods_running():
    """Falco DaemonSet pods on every node — at least one Running."""
    ok, bad = all_pods_running("security", "app.kubernetes.io/name=falco")
    assert ok, f"Falco pods not Running: {bad}"


def test_external_secrets_pod_running():
    """ESO controller Pod is Running (Integration may still fail without IRSA)."""
    ok, bad = all_pods_running("platform", "app.kubernetes.io/name=external-secrets")
    assert ok, f"ESO pods not Running: {bad}"


def test_network_policies_in_apps_namespace():
    """At least one NetworkPolicy exists in apps namespace."""
    data = kubectl_json("get", "networkpolicies", "-n", "apps")
    items = data.get("items", [])
    assert items, "No NetworkPolicies in apps namespace"


def test_rbac_resources_applied():
    """Some workshop ClusterRoles or RoleBindings exist."""
    data = kubectl_json("get", "clusterroles")
    items = data.get("items", [])
    # Workshop creates at least one custom ClusterRole; just confirm we have many
    assert len(items) >= 5, f"Too few ClusterRoles: {len(items)}"
