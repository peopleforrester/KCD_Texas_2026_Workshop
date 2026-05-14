# Phase 4 — Observability

**Skills:** `.claude/skills/kube-prometheus-stack.md`, `.claude/skills/otel-wiring.md`
**Ground truth:** `gitops/apps/{kube-prometheus-stack,grafana-dashboards,argocd-servicemonitors,otel-collector,loki,promtail,tempo}.yaml`
**Test gate:** `tests/test_phase_04_observability.py`

---

## Goal

Wait for the observability stack to reach Healthy:
- kube-prometheus-stack: Prometheus + Grafana + Operator + kube-state-metrics + node-exporter DaemonSet
- Grafana dashboards (provisioned via ConfigMap sidecar)
- ArgoCD ServiceMonitors (3 of them — server, controller, repo-server) → ArgoCD metrics scraped by Prometheus
- OTel Collector DaemonSet on every node
- Loki for log aggregation, Promtail as the log shipper, Tempo for traces

By end of phase, Prometheus scrape targets are all `up`, Grafana renders the platform-overview dashboard, OTel pods are healthy, logs are flowing into Loki.

## The prompt I paste to Claude

```
Read .claude/skills/kube-prometheus-stack.md and .claude/skills/otel-wiring.md
and spec/phases/phase-04-observability.md.

Phase 4 components are already reconciling from Phase 2's app-of-apps. Wait
for the observability stack to reach Healthy, then verify:

  1. kubectl get pods -n monitoring  (prometheus-stack-* all Running)
  2. kubectl get servicemonitors -A   (>= 10 including ArgoCD scrape targets)
  3. kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
  4. kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
  5. kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

Port-forward Grafana and confirm dashboards render:
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
  # Browser: http://localhost:3000 (admin / kcd-texas)
  # Dashboards → Platform Overview → should populate within 30s

Then run: pytest tests/test_phase_04_observability.py -v

When the gate passes:
<promise>PHASE_4_DONE</promise>
```

## Known failure modes

- **Prometheus doesn't discover externally-created ServiceMonitors.** Default behavior selects only ServiceMonitors with the chart's release label. The workshop ground truth at `gitops/apps/kube-prometheus-stack.yaml` sets `serviceMonitorSelectorNilUsesHelmValues: false` — without this, the ArgoCD ServiceMonitors are silently ignored. Skill file calls this out.
- **OTel Collector chart 0.145+ requires explicit `image.repository`.** Breaking change from 0.89 line. The kubeauto skill (otel-wiring.md) captures the right values.
- **ArgoCD ServiceMonitor selectors wrong.** The metrics Service is labeled `argocd-server-metrics`, not `argocd-server`. Port name is `http-metrics`, not `metrics`. Workshop ground truth (`gitops/manifests/argocd-servicemonitors/`) has the verified-correct selectors — confirmed via `helm template` of the live chart.
- **Loki Pod in `CrashLoopBackOff` with `failed to start: directory not writable`.** Default Loki chart wants persistent storage. Workshop uses ephemeral; ensure `loki.persistence.enabled: false` or accept that Loki won't survive a Pod restart (fine for 90 min).
- **Grafana admin password mismatch.** Workshop ground truth pins `adminPassword: kcd-texas`. If a student changes the values, password is whatever they set.

## What students see on their cluster

The dashboards render the same on every cluster because Prometheus scrapes the same in-cluster metrics. Grafana password is `kcd-texas` (workshop-pinned).

## Score on the live scorecard

**Components covered:** Prometheus + Grafana, OTel Collector Config, Grafana Dashboards, Alert Rules (4 of 27)

- **Install:** Did all 5 stack pods (Prometheus, Grafana, Operator, kube-state-metrics, node-exporter) come up on first reconciliation?
- **Integration:** Are the ServiceMonitors being discovered? Are the ArgoCD scrape targets `up` in Prometheus? Is OTel forwarding to Prometheus via remote-write? Are alert rules loaded?
- **Usability:** Does the Platform Overview dashboard make sense to a developer? Are the panels showing the right data? Are queries cached enough that the UI doesn't lag?

The kube-prometheus-stack chart is the "AI does this cleanly" component — high Install, high Integration. Where Usability dings is the *default* Grafana dashboards being overwhelmingly dense. That's the workshop's honest data on observability tooling.

Move to Phase 5.
