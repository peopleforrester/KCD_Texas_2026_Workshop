# kube-prometheus-stack Skill

Use this skill **before generating the Prometheus + Grafana Application.** The workshop uses `kube-prometheus-stack` chart `84.5.0` with intentional workshop-lean values (alertmanager disabled, short retention, ServerSideApply required for the chart's large CRDs).

## Critical version pins

| Thing | Workshop value |
|---|---|
| Helm chart | `prometheus-community/kube-prometheus-stack` |
| Chart version | `84.5.0` |
| Prometheus operator app version | `v0.90.x` |
| Grafana version | `11.x` |
| Workshop retention | `2h` (chart default is 10d) |
| Workshop alertmanager | `disabled` |
| Required syncOption | `ServerSideApply=true` (the chart's CRDs exceed annotation size limit) |

## What this single chart installs

A complete observability stack — one chart, many workloads. Verified against `helm template kube-prometheus-stack 84.5.0`:

| Resource | What it does |
|---|---|
| `prometheus-operator` Deployment | Watches ServiceMonitor / PodMonitor / Prometheus CRs and reconciles them |
| `prometheus-<chart>-prometheus-0` StatefulSet | The Prometheus instance itself — scrapes metrics, runs the rule engine |
| `kube-prometheus-stack-grafana` Deployment | Grafana UI with pre-provisioned dashboards |
| `kube-prometheus-stack-kube-state-metrics` Deployment | Translates Kubernetes API objects → Prometheus metrics |
| `prometheus-node-exporter` DaemonSet | Per-node OS / hardware metrics |
| ~10+ ServiceMonitors | Auto-created by the chart, scrape kubelet, apiserver, kube-controller-manager, etc. |
| ~6 CRDs | Prometheus, ServiceMonitor, PodMonitor, PrometheusRule, AlertmanagerConfig, ThanosRuler |
| Default dashboards (ConfigMap) | Kubernetes / Compute Resources / Cluster, Pod, Namespace, etc. |

## Pattern 1 — Workshop Application values

Matches `gitops/apps/kube-prometheus-stack.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: "84.5.0"
    helm:
      valuesObject:
        grafana:
          adminPassword: "kcd-texas"     # Workshop-known credential
        prometheus:
          prometheusSpec:
            retention: 2h                # Workshop: 2 hours is plenty
        alertmanager:
          # Disabled for workshop — keeps the install lean, avoids paging
          # on transient install-time alerts. Production would enable this.
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true             # CRITICAL — see explanation below
```

## Why ServerSideApply is mandatory for this chart

The Prometheus operator's CRDs are large. `prometheuses.monitoring.coreos.com` alone is several thousand lines. ArgoCD by default tries to set `kubectl.kubernetes.io/last-applied-configuration` annotation on every applied object — but Kubernetes caps annotations at 256 KB. The CRD blows the cap.

Without `ServerSideApply=true`:
- ArgoCD applies the CRD with the giant annotation
- Kubernetes rejects the annotation
- ArgoCD considers the resource OutOfSync
- Reconcile loop fires every 30 seconds, every loop fails the same way
- Your Application sits at `OutOfSync` forever, even though the CRD is actually installed

With `ServerSideApply=true`:
- ArgoCD uses server-side apply (no last-applied annotation needed)
- Reconcile loop is clean
- Application reaches `Synced/Healthy` in ~2 minutes

## Pattern 2 — Why alertmanager is disabled for workshop

Default chart values enable Alertmanager:
- Adds 2 pods (alertmanager + alertmanager-operated)
- Adds a StatefulSet with persistence (may stick Pending without a default StorageClass)
- Starts firing transient alerts during install (Watchdog, NodeNotReady on cluster bootstrap)

Workshop-lean: disable it. You lose nothing visible to the workshop, you save a couple minutes of install time, and you avoid the noise.

## Pattern 3 — Why retention is 2h (not 10d default)

The workshop cluster has limited disk. 10 days of retention is fine on a real cluster but wasteful when the cluster will be destroyed in 90 minutes. 2h keeps Prometheus's WAL small and the chart install fast.

## Pattern 4 — How Prometheus knows what to scrape

Two layers:
1. The Prometheus operator watches `ServiceMonitor` and `PodMonitor` resources
2. The chart auto-creates ServiceMonitors for: kubelet, apiserver, kube-controller-manager, kube-scheduler, kube-state-metrics, node-exporter, coredns, and itself

So scrape works out of the box. **The interesting workshop question:** does Prometheus scrape ArgoCD or Kyverno? It doesn't by default — neither chart ships a ServiceMonitor. **That's a Phase 3 integration question for the scorecard:** Install scored well, Integration may not.

## Common failure modes

| What you see | Cause | Fix |
|---|---|---|
| Application stuck `Progressing` for >5 min | First sync is slow (operator → CRDs → custom resources) | Wait. Normal first-sync time is 2–4 minutes. |
| Application loops between `OutOfSync` and `Syncing` | Missing `ServerSideApply=true` | Add it to syncOptions |
| Prometheus StatefulSet Pod stuck `Pending` | PVC needs a StorageClass that doesn't exist on this cluster | The workshop cluster has a default StorageClass; if Pending, check `kubectl describe pvc -n monitoring` |
| Grafana shows "No data" on every panel | Prometheus hasn't scraped yet (first scrape ~30s after pod ready) OR ServiceMonitor selector mismatch | Wait 60s. If still empty, check `kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090` → Status → Targets |
| Alertmanager not present | `alertmanager.enabled: false` (intentional for workshop) | Not a bug |

## Verify commands

```bash
# All pods Running in monitoring
kubectl get pods -n monitoring
# Expected:
#   alertmanager-kube-prometheus-stack-alertmanager-0  (only if alertmanager.enabled=true)
#   kube-prometheus-stack-grafana-<hash>
#   kube-prometheus-stack-kube-state-metrics-<hash>
#   kube-prometheus-stack-operator-<hash>
#   prometheus-kube-prometheus-stack-prometheus-0
#   prometheus-node-exporter-<hash>  (one per node)

# ServiceMonitors auto-created
kubectl get servicemonitor -n monitoring
# Expected: ~10+ entries

# ArgoCD Application Healthy
kubectl get application kube-prometheus-stack -n argocd

# Open Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
# Browser: http://localhost:3000
# User: admin
# Password: kcd-texas
# Dashboards → "Kubernetes / Compute Resources / Cluster" should show populated data

# Open Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
# Browser: http://localhost:9090
# Status → Targets — should show ~30 healthy targets across the cluster
```

## What NOT to generate

- `alertmanager.enabled: true` — workshop disables this
- `prometheus.prometheusSpec.retention: 10d` (default) — too long for workshop disk
- `helm.values: |` as a string — use `helm.valuesObject:`
- A separate Grafana Application — the chart bundles Grafana, don't add a second one
- Custom dashboards as additional ConfigMaps — the chart's default dashboards are sufficient for the workshop scope
- A persistent-storage override for Prometheus — workshop cluster's default StorageClass works

## What to optionally add (out of workshop scope but worth knowing)

- A `ServiceMonitor` for ArgoCD to scrape its metrics — this turns "Install 9, Integration 5" into "Install 9, Integration 8" on the scorecard. The ServiceMonitor would live in `monitoring` namespace, select pods in `argocd` namespace using `namespaceSelector.matchNames: [argocd]`. Out of scope for 90 minutes, but a natural follow-on.
