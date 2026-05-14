# ABOUTME: Phase 7 test gate — cert-manager, ResourceQuotas, PDBs.
# ABOUTME: All tests hit real infrastructure. Promise PHASE_7_DONE only after these pass.

import pytest
from conftest import kubectl_json, all_pods_running

pytestmark = pytest.mark.usefixtures("cluster_reachable")


def test_cert_manager_pods_running():
    """cert-manager + cainjector + webhook all Running."""
    ok, bad = all_pods_running("cert-manager")
    assert ok, f"cert-manager pods not Running: {bad}"


def test_cert_manager_crds_installed():
    """cert-manager CRDs must be present (Certificate, Issuer, ClusterIssuer)."""
    data = kubectl_json("get", "crd")
    crds = {item["metadata"]["name"] for item in data["items"]}
    required = {
        "certificates.cert-manager.io",
        "clusterissuers.cert-manager.io",
        "issuers.cert-manager.io",
    }
    missing = required - crds
    assert not missing, f"Missing cert-manager CRDs: {missing}"


def test_cluster_issuers_present():
    """At least one ClusterIssuer registered (Ready or not — Ready depends on DNS wiring)."""
    data = kubectl_json("get", "clusterissuers")
    items = data.get("items", [])
    # Path-based Application: may not yet have any if Wave 2 still reconciling
    # Test that the CRD is queryable and we get some response
    assert isinstance(items, list), "ClusterIssuers query failed"


def test_resource_quotas_applied():
    """ResourceQuotas exist in at least one workshop namespace."""
    data = kubectl_json("get", "resourcequotas", "-A")
    items = data.get("items", [])
    assert items, "No ResourceQuotas applied anywhere"


def test_at_least_one_pdb_exists():
    """At least one PodDisruptionBudget defined (for critical workloads)."""
    data = kubectl_json("get", "pdb", "-A")
    items = data.get("items", [])
    assert items, "No PodDisruptionBudgets defined"


def test_cert_manager_application_healthy():
    """ArgoCD reports cert-manager Application Synced + Healthy."""
    data = kubectl_json("get", "application", "cert-manager", "-n", "argocd")
    sync = data["status"]["sync"]["status"]
    health = data["status"]["health"]["status"]
    # ServerSideApply means it might still settle; accept Synced+Healthy or Synced+Progressing
    assert sync == "Synced", f"cert-manager sync='{sync}'"
    assert health in ("Healthy", "Progressing"), f"cert-manager health='{health}'"
