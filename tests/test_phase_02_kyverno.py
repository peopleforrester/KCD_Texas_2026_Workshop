# ABOUTME: Phase 2 test gate — Kyverno admission controller + 3 ClusterPolicies.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_2_DONE only after these pass.

import pytest
from conftest import kubectl, kubectl_json, kubectl_returns_error, all_pods_running


pytestmark = pytest.mark.usefixtures("cluster_reachable")

REQUIRED_POLICIES = {"require-labels", "require-resource-limits", "disallow-privileged"}


def test_kyverno_controllers_running():
    """All four Kyverno controllers should be Running: admission, background, cleanup, reports."""
    ok, bad = all_pods_running("kyverno")
    assert ok, f"Non-running pods in kyverno namespace: {bad}"


def test_three_cluster_policies_loaded():
    """All three workshop ClusterPolicies are present."""
    data = kubectl_json("get", "clusterpolicies")
    names = {item["metadata"]["name"] for item in data["items"]}
    missing = REQUIRED_POLICIES - names
    assert not missing, f"Missing ClusterPolicies: {missing}"


def test_all_policies_are_enforce_mode():
    """Policies must be Enforce mode (case-sensitive) — not Audit, not enforce lowercase."""
    data = kubectl_json("get", "clusterpolicies")
    bad = []
    for item in data["items"]:
        name = item["metadata"]["name"]
        if name not in REQUIRED_POLICIES:
            continue
        action = item["spec"].get("validationFailureAction", "MISSING")
        if action != "Enforce":
            bad.append((name, action))
    assert not bad, f"Policies not in Enforce mode: {bad}"


def test_all_policies_ready():
    """Policies must report Ready in their status."""
    data = kubectl_json("get", "clusterpolicies")
    bad = []
    for item in data["items"]:
        name = item["metadata"]["name"]
        if name not in REQUIRED_POLICIES:
            continue
        conditions = item.get("status", {}).get("conditions", [])
        ready = next((c for c in conditions if c.get("type") == "Ready"), None)
        if not ready or ready.get("status") != "True":
            bad.append((name, ready))
    assert not bad, f"Policies not Ready: {bad}"


def test_admission_blocks_noncompliant_pod():
    """A pod without required labels in apps namespace must be REJECTED at admission."""
    result = kubectl_returns_error(
        "run", "test-bad-admission", "--image=nginx",
        "-n", "apps", "--restart=Never",
        "--rm", "--dry-run=server",
    )
    # Cleanup just in case dry-run somehow created it
    kubectl_returns_error("delete", "pod", "test-bad-admission", "-n", "apps", "--ignore-not-found")
    assert result.returncode != 0, "Non-compliant pod was accepted; admission should have denied"
    assert "denied" in result.stderr.lower() or "policy" in result.stderr.lower(), \
        f"Pod rejected but not by policy: {result.stderr}"


def test_system_namespaces_unaffected():
    """The webhook namespaceSelector must exclude system namespaces — kube-system pods stay Running."""
    ok, bad = all_pods_running("kube-system")
    assert ok, f"kube-system pods affected (webhook scope wrong?): {bad}"
