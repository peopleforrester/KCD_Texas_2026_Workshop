# ABOUTME: Shared pytest fixtures for the KCD Texas 2026 IDP test gates.
# ABOUTME: All tests hit real infrastructure via kubectl — no mocks, no stubs.

import json
import subprocess
import pytest


def kubectl(*args, timeout=30):
    """Run kubectl with the given args. Returns CompletedProcess. Raises on non-zero exit."""
    result = subprocess.run(
        ["kubectl", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"kubectl {' '.join(args)} failed (exit {result.returncode}):\n"
            f"STDOUT: {result.stdout}\n"
            f"STDERR: {result.stderr}"
        )
    return result


def kubectl_json(*args, timeout=30):
    """Run kubectl with -o json and return parsed output. Raises on non-zero exit or unparseable JSON."""
    result = kubectl(*args, "-o", "json", timeout=timeout)
    return json.loads(result.stdout)


def kubectl_returns_error(*args, timeout=30):
    """Run kubectl expecting non-zero exit (e.g., admission denial). Returns CompletedProcess regardless."""
    return subprocess.run(
        ["kubectl", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


@pytest.fixture(scope="session")
def cluster_reachable():
    """Confirm we can talk to a cluster before running anything else."""
    try:
        kubectl("get", "nodes", timeout=10)
    except (RuntimeError, FileNotFoundError, subprocess.TimeoutExpired) as e:
        pytest.fail(f"No cluster reachable via kubectl: {e}")
    return True


def all_pods_running(namespace: str, label_selector: str = None) -> tuple[bool, list]:
    """Return (True, []) if every pod in the namespace (optionally filtered) is Running
    or Succeeded (e.g., finished Job pods like kyverno-migrate-resources).
    Else (False, [list of (pod_name, phase) for unhealthy pods])."""
    args = ["get", "pods", "-n", namespace]
    if label_selector:
        args += ["-l", label_selector]
    data = kubectl_json(*args)
    bad = []
    for item in data["items"]:
        phase = item["status"].get("phase", "Unknown")
        if phase not in ("Running", "Succeeded"):
            bad.append((item["metadata"]["name"], phase))
    return (len(bad) == 0, bad)


def cluster_type() -> str:
    """Read the cluster-type marker file written by Phase 1's detection step.
    Returns one of: 'eks', 'kubeadm', or 'unknown' (if the marker file is missing
    or the value isn't recognized). Tests that need to branch behavior call this
    helper rather than re-running kubectl context inspection — the marker file
    is the canonical signal per spec/phases/phase-01-foundation.md."""
    import os
    from pathlib import Path
    repo_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", "")).resolve() \
        if os.environ.get("CLAUDE_PROJECT_DIR") \
        else Path(__file__).resolve().parent.parent
    marker = repo_root / ".cluster-type"
    if not marker.exists():
        return "unknown"
    val = marker.read_text().strip().lower()
    if val in ("eks", "kubeadm"):
        return val
    return "unknown"


def is_eks() -> bool:
    return cluster_type() == "eks"


def is_kubeadm() -> bool:
    return cluster_type() == "kubeadm"
