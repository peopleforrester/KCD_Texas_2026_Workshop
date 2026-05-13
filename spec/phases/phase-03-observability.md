# Phase 3 — kube-prometheus-stack (Prometheus + Grafana)

**Skill:** `.claude/skills/kube-prometheus-stack.md`
**Ground truth:** `gitops/apps/kube-prometheus-stack.yaml`

---

## Goal

The kube-prometheus-stack Application is already deploying via Phase 1's app-of-apps (sync wave 1). By the time we reach Phase 3, Prometheus and Grafana should be up. We have Claude explain what the single chart actually installed (Prometheus operator + Prometheus + Grafana + node-exporter + kube-state-metrics + ~10 ServiceMonitors), generate an equivalent Application live, diff against the pre-committed reference, then **port-forward Grafana onto the projector** and see whether dashboards are actually populated.

This is the phase where Install scores high but Integration may not. The chart installs fine. Does it actually scrape ArgoCD? That's the integration question, and it's the talk's central moment.

## What the audience sees

- The pre-committed chart is already deploying (visible in ArgoCD UI)
- I have Claude explain the chart's contents structurally
- I have Claude generate an equivalent Application live
- I port-forward Grafana, open a real dashboard on the projector, and the room watches to see whether the panels have data or not
- The Integration column on the live scorecard fills in based on what they see

## The prompt I paste to Claude

```
Read .claude/skills/kube-prometheus-stack.md and spec/phases/phase-03-observability.md.

First, walk me through gitops/apps/kube-prometheus-stack.yaml and explain:
  1. What does this single chart install? List every workload by type
     (Deployment / StatefulSet / DaemonSet) — there are more than people expect.
  2. The ground truth disables alertmanager (alertmanager.enabled: false). Why?
     What would we lose vs production?
  3. How does Prometheus know what to scrape? Walk the chain: Prometheus →
     Prometheus Operator → ServiceMonitor → Service. How does this chart wire
     it automatically? And what's NOT auto-scraped — ArgoCD, for instance?

Second, generate an equivalent Application:
  - File: ~/my-kube-prometheus-stack.yaml
  - Name: kube-prometheus-stack, sync wave 1
  - Chart: kube-prometheus-stack from
    https://prometheus-community.github.io/helm-charts, version 84.5.0
  - Destination namespace: monitoring
  - Values: grafana.adminPassword: kcd-texas,
            prometheus.prometheusSpec.retention: 2h,
            alertmanager.enabled: false
  - syncOptions: CreateNamespace=true, ServerSideApply=true
    (the chart's CRDs exceed the default annotation size limit without SSA)

Third, diff and walk through:
  diff ~/my-kube-prometheus-stack.yaml gitops/apps/kube-prometheus-stack.yaml

Then I'll port-forward Grafana and we'll check whether the default dashboards
have non-zero data.

When the gate below passes, output:
<promise>PHASE_3_DONE</promise>
```

## The test gate

```bash
# Gate 1: All pods Running in monitoring
kubectl get pods -n monitoring
# Expected: prometheus-kube-prometheus-stack-prometheus-0,
#           kube-prometheus-stack-grafana-*,
#           kube-prometheus-stack-operator-*,
#           kube-prometheus-stack-kube-state-metrics-*,
#           prometheus-node-exporter-* (one per node)
# All Running. No alertmanager (disabled by design).

# Gate 2: ServiceMonitors auto-created by the chart
kubectl get servicemonitor -n monitoring
# Expected: ~10+ entries (apiserver, kubelet, kube-state-metrics, etc.)

# Gate 3: ArgoCD Application Healthy
kubectl get application kube-prometheus-stack -n argocd
# Expected: SYNC = Synced, HEALTH = Healthy

# Gate 4: Open Grafana on the projector
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
# Browser to http://localhost:3000
# Username: admin, password: kcd-texas
# Click Dashboards → "Kubernetes / Compute Resources / Cluster"

# Gate 5: Visual gate — dashboards have non-zero data
# Expected on screen: CPU usage panel shows actual numbers, not "No data"
# If "No data" everywhere, wait 60 seconds (first scrape) and refresh.
# If still empty after 60s, the integration is broken — score Integration accordingly.
```

If gates 1–4 pass and gate 5 shows real data, score and move to Phase 4. If gate 5 fails (the panels are empty), narrate the failure honestly — "the chart installed but the dashboards aren't populated, here's the diagnostic" — and score Integration low.

## Known failure modes (narrate live)

- **Missing `ServerSideApply=true`.** The Prometheus operator's CRDs exceed the 256 KB annotation limit. Without SSA, ArgoCD loops on the CRDs forever, never reaches Healthy. Most common silent failure for this chart in GitOps.
- **`alertmanager.enabled: true`** (default). Extra pods, persistence may stick Pending without a default StorageClass, transient install-time alerts fire. Workshop disables it.
- **Retention default of 10d.** Wastes workshop cluster disk. Ground truth uses `2h`.
- **Dashboards empty.** Could be: first scrape hasn't completed (wait 60s), ServiceMonitor selector mismatch (rarely), or Grafana provisioner didn't pick up the dashboards (rarer). Diagnose by hitting Prometheus's own UI (`kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090`) and checking Status → Targets.

## What students see on their cluster

Theirs is reconciling the same chart from the same pre-committed Application. They run the same `kubectl port-forward` command and check Grafana on their localhost. Their score on the Integration row matches mine (or doesn't — if their cluster's first scrape didn't fire yet but mine did, theirs is honest data: their AI-assisted observability "installed but didn't show data within 60 seconds").

## Score on the live scorecard

**Row: kube-prometheus-stack**
- Install — Did Claude's generated Application install cleanly via ArgoCD? Was ServerSideApply set? Was alertmanager handled correctly?
- Integration — Is Prometheus actually scraping? Are dashboards populated? **This is the dimension where AI struggles most cleanly on this phase** — score honestly.
- Usability — Can I find my cluster's CPU metrics in Grafana within 60 seconds of opening it? Are the default dashboard names obvious for a developer who's never used Grafana?

This is the phase that anchors the talk's "Install ≫ Integration ≫ Usability" claim. Don't soften the Integration score if dashboards are dark.

Move to Phase 4 (or, if time's up, play the pre-recorded Backstage segment during closing).
