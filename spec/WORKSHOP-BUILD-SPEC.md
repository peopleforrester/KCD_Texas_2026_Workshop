# KCD Texas 2026 — "The 90-Minute IDP" Workshop Build Spec

This is the **condensed 4-phase build spec** the workshop's `/workshop-phase`
command reads. It is derived from
[`kubeauto-ai-day/spec/BUILD-SPEC.md`](https://github.com/peopleforrester/kubeauto-ai-day/blob/main/spec/BUILD-SPEC.md)
— the full 7-phase, ~10-hour overnight build — condensed for a 90-minute
hands-on workshop.

## Mapping to kubeauto's reference build

| Workshop Phase | Reference (kubeauto) Phase | What's dropped |
|---|---|---|
| **Phase 0 (pre-provisioned)** | Phase 1: Foundation (60 min) | Done by Terraform before workshop. Students don't touch this. |
| **Phase 1: Bootstrap** | Phase 2: GitOps Bootstrap (90 min) | ApplicationSets, project-scoped RBAC (workshop uses `default` project) |
| **Phase 2: Policy** | Phase 3: Security Stack (120 min) | Falco, ESO, RBAC lock-down, NetworkPolicies. Kyverno reduced from 6 policies to 3. |
| **Phase 3: Observability** | Phase 4: Observability (90 min) | OTel Collector, sample-app instrumentation. Kept: kube-prometheus-stack (Prom+Grafana), one PrometheusRule, ArgoCD ServiceMonitors. |
| **Phase 4: Portal** | Phase 5: Developer Portal (90 min) | Custom Backstage build (workshop uses community image), second template, TechDocs, plugin wiring |
| _(post-workshop)_ | Phases 6–7: Integration + Hardening | Out of time. Students extend on their own. |

Total student build time: 4 × ~20 min = ~80 min, plus 5 min preflight and 5
min wrap-up.

---

## Phase 1 — Bootstrap ArgoCD + app-of-apps

**Goal:** ArgoCD running in `argocd`, app-of-apps root applied, four child
Applications discovered and progressing.

**Inputs:** Pre-provisioned EKS cluster with the workshop namespaces created
(`argocd`, `kyverno`, `monitoring`, `backstage`, `apps`, `sample-app`).

**Outputs:**
- ArgoCD installed via Helm chart `argo-cd` 9.5.x (deploys ArgoCD 3.3.x)
- `configs.cm."timeout.reconciliation": "30s"` set (workshop demo pace)
- `controller.metrics.enabled` / `server.metrics.enabled` /
  `repoServer.metrics.enabled` all true (so the metrics Services exist for
  the Phase 3 ServiceMonitors to target)
- Root `app-of-apps` Application applied via `kubectl apply -f gitops/bootstrap/app-of-apps.yaml`
- Five child Applications visible: `kyverno`, `kyverno-policies`,
  `kube-prometheus-stack`, `argocd-servicemonitors`, `backstage`

**Verify:**
```bash
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller,
# argocd-redis -- all Running.

kubectl get application -n argocd
# Expected: app-of-apps Synced/Healthy + five children at least Progressing.
```

**Completion promise:** `<promise>WORKSHOP_PHASE_1_DONE</promise>`

---

## Phase 2 — Kyverno admission + 3 policies

**Goal:** Kyverno admission controller running, three ClusterPolicies enforcing
on the `apps` namespace, demonstrably blocking non-compliant pods.

**Outputs:**
- Kyverno chart 3.8.x installed (via the `kyverno` Application that
  auto-synced in Phase 1, sync wave -5)
- Three ClusterPolicies applied (via the `kyverno-policies` Application,
  sync wave -4): `require-labels`, `require-resource-limits`,
  `disallow-privileged`
- Webhook `namespaceSelector` excludes system namespaces so policies only
  fire on `apps`

**Verify:**
```bash
kubectl get pods -n kyverno
# Expected: kyverno-admission, kyverno-background, kyverno-cleanup,
# kyverno-reports -- all Running.

kubectl get clusterpolicy
# Expected: 3 policies, all VALIDATE ACTION=Enforce, READY=true.

kubectl run test-bad --image=nginx -n apps
# Expected: admission webhook denies (require-labels + require-resource-limits).

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata: { name: test-good, namespace: apps, labels: { app: demo, team: workshop } }
spec:
  containers: [ { name: app, image: nginx, resources: { limits: { cpu: 100m, memory: 128Mi } } } ]
EOF
# Expected: pod/test-good created.
```

**Completion promise:** `<promise>WORKSHOP_PHASE_2_DONE</promise>`

---

## Phase 3 — kube-prometheus-stack + ArgoCD ServiceMonitors

**Goal:** Prometheus and Grafana running, Grafana dashboards populated,
Prometheus scraping ArgoCD's metrics endpoints.

**Outputs:**
- `kube-prometheus-stack` chart 84.5.x installed (sync wave 1)
- Grafana admin password set to `kcd-texas` for the workshop
- Alertmanager disabled (workshop-lean)
- `serviceMonitorSelectorNilUsesHelmValues: false` (and friends) so
  Prometheus auto-discovers external ServiceMonitors
- ArgoCD ServiceMonitors applied (sync wave 2, after CRD registers in wave 1)

**Verify:**
```bash
kubectl get pods -n monitoring
# Expected: prometheus-*, grafana-*, prometheus-operator-*, kube-state-metrics-*,
# node-exporter-* (one per node). All Running.

kubectl get servicemonitor -A
# Expected: ServiceMonitors for ArgoCD's server, application-controller, repo-server.

kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
# Open http://localhost:3000  (admin / kcd-texas)
# Dashboards -> "Kubernetes / Compute Resources / Cluster" should be populated.
# Explore -> Prometheus -> query `argocd_app_info` -> should return non-empty.
```

**Completion promise:** `<promise>WORKSHOP_PHASE_3_DONE</promise>`

---

## Phase 4 — Backstage portal

**Goal:** Backstage running, catalog visible, students can navigate the portal.

**Outputs:**
- Backstage chart 2.7.x installed (sync wave 5)
- Image: `roadiehq/community-backstage-image:1.50.4` (workshop default;
  students can swap for a custom-built image post-workshop)
- ClusterIP service on port 7007

**Verify:**
```bash
kubectl get pods -n backstage
# Expected: backstage-* pod Running.  May take 60-90s after Phase 1 to come up
# due to image pull + Postgres init.

kubectl port-forward -n backstage svc/backstage 7007:7007 &
# Open http://localhost:7007 -- catalog should render the community image's
# default entries.  A workshop-published image would replace these with our own.
```

**Completion promise:** `<promise>WORKSHOP_PHASE_4_DONE</promise>` and
`<promise>WORKSHOP_COMPLETE</promise>`

---

## Known correction patterns from the kubeauto reference build

These are mistakes Claude Code made during the kubeauto overnight build that
the workshop should NOT repeat. The skill files in `.claude/skills/` encode
the correct patterns. If Claude generates one of these anti-patterns, stop
and reference the skill file.

| Anti-pattern | Correct pattern |
|---|---|
| ArgoCD `targetRevision: "7.8.*"` (chart 7.x maps to older ArgoCD 3.x) | Chart `9.5.*` for current ArgoCD 3.3.x |
| `configs.params."timeout.reconciliation"` for the demo sync interval | `configs.cm."timeout.reconciliation"` — the former silently writes to the wrong ConfigMap |
| Kyverno webhook `namespaceSelector` as a list | Map keyed by `matchExpressions` or `matchLabels` |
| Kyverno policies Application without `ServerSideApply=true` | Include `ServerSideApply=true` — CRD annotation can exceed 256KB |
| Backstage `createServiceBuilder()` / `@backstage/backend-common` | `createBackend()` from `@backstage/backend-defaults` — legacy backend was removed in early 2025 |
| Backstage chart with no image specified | Set `backstage.image.repository` + `backstage.image.tag` — chart has no default image |
| ArgoCD ServiceMonitors created in Phase 1 (before CRD exists) | Apply at sync wave 2 via `argocd-servicemonitors` Application, after kube-prom-stack registers the CRD in wave 1 |
| Prometheus ignores externally-created ServiceMonitors | `serviceMonitorSelectorNilUsesHelmValues: false` on kube-prom-stack |
| `kubectl apply` from the provisioner laptop to grant student access (legacy aws-auth) | `aws eks create-access-entry` + `aws eks associate-access-policy AmazonEKSClusterAdminPolicy` |
| Pre-pull images pinned to versions that don't match the chart's deployed images | Pre-pull tags must track `gitops/apps/*.yaml` chart pins; update both together |

---

## Scorecard

After each phase, the student fills the per-phase row in
[`scorecard/SCORECARD-TEMPLATE.md`](../scorecard/SCORECARD-TEMPLATE.md):

- AI time (wall clock minutes)
- Correction cycles (distinct corrective prompts you sent)
- Toil reduced (1–10 honest estimate)
- Integration (1–10, did the component do its job end-to-end)
- Tour or DIY
- Notes (one line, optional)

Wrap-up reflection (filled once at the end): manual-time estimate,
toil-shifted question, **usability rating**, where AI helped most, where it
struggled, takeaway.

The reference (kubeauto overnight build) totals are at
`kubeauto-ai-day/spec/SCORECARD.md`: 27 components, 3h 10m AI time, 73.8% net
toil reduction, 41% zero-correction rate. Your workshop numbers will be
different — the workshop is a 4-component tour-or-build under time pressure,
not an overnight solo build. The variance is the data the presenter scorecard
captures.
