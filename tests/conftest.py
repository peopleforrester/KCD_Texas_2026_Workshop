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
