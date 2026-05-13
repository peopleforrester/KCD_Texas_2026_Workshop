# KCD Texas 2026 — "The 90-Minute IDP" Workshop Build Spec

The canonical build spec the workshop's `/workshop-phase` command reads. Also
the document a human (presenter, TA, replicator, or student) can follow
manually, command by command, to walk through the workshop without Claude
Code if needed.

Derived from [`kubeauto-ai-day/spec/BUILD-SPEC.md`](https://github.com/peopleforrester/kubeauto-ai-day/blob/main/spec/BUILD-SPEC.md)
(the full 7-phase, ~10-hour overnight build), condensed to 4 phases × ~20 min.

---

## How to use this spec

**For students (the default path):** open Claude Code in the workshop repo and
type `/workshop-phase 1`. Claude reads this spec, the relevant skill files,
and the reference manifests in `gitops/apps/`, then builds and verifies the
phase. When the verify step passes Claude emits a completion promise. Move
to Phase 2 with `/workshop-phase 2`. Repeat through Phase 4.

**For manual testing or presenters going off-script:** the per-phase blocks
below contain every literal command (`helm install ...`, `kubectl apply ...`,
`kubectl port-forward ...`) and every expected output, in the order they run.
A human can walk through phase-by-phase without Claude Code and end at the
same state.

**For replicators (Accenture, other workshop hosts):** this spec is the
contract. Anything in `gitops/apps/`, `.claude/skills/`, or the playbook is
implementation of these phases. The "Known correction patterns" table at the
bottom captures every gotcha the kubeauto reference build hit so you don't
repeat them.

---

## Pre-conditions (Phase 0, done before students arrive)

Each student walks in to a cluster where the workshop organizers have already:

1. **Provisioned an EKS cluster** named `kcd-texas-student-NN` (per
   `kcd-texas-provisioning/terraform/`). 3× t3.xlarge nodes, K8s 1.34, AWS
   region `us-east-2`, EKS Access Entries auth (no `aws-auth` ConfigMap).

2. **Created six workshop namespaces** (per
   `kcd-texas-provisioning/post-provision-setup.sh`):
   - `argocd` — ArgoCD itself + ServiceMonitors
   - `kyverno` — Kyverno admission controller
   - `monitoring` — kube-prometheus-stack
   - `backstage` — Backstage portal
   - `apps` — user workloads (Kyverno policies enforce here)
   - `sample-app` — workshop demo workload namespace

3. **Pre-pulled container images** onto every node via the
   `image-prepull` DaemonSet:
   - `quay.io/argoproj/argocd:v3.3.9`
   - `ghcr.io/kyverno/kyverno:v1.18.0` + `ghcr.io/kyverno/cleanup-controller:v1.18.0`
   - `quay.io/prometheus/prometheus:v3.11.3`
   - `docker.io/grafana/grafana:12.3.0`
   - `quay.io/prometheus-operator/prometheus-operator:v0.90.1`
   - `roadiehq/community-backstage-image:1.50.4`

4. **Created a per-student IAM user** (`kcd-texas-student-NN`) with:
   - Permissions boundary (`kcd-texas-student-boundary`) scoping AWS access to EKS-related services
   - Inline policy scoping `eks:*` to the student's own cluster ARN
   - An EKS Access Entry + `AmazonEKSClusterAdminPolicy` at cluster scope (full kubectl admin in their own cluster)
   - An access key (handed out on the connection card)

5. **Distributed connection cards** containing AWS keys, cluster name, and
   workshop repo URL.

### Student preflight (5 min)

```bash
# 1. Configure AWS with the keys on the connection card
aws configure
#   AWS Access Key ID:     <from card>
#   AWS Secret Access Key: <from card>
#   Default region:        us-east-2
#   Default output format: json

# 2. Verify the identity
aws sts get-caller-identity
# Expected: { "Account": "515966504359", "Arn": "arn:aws:iam::...:user/kcd-texas-student-NN", ... }

# 3. Configure kubectl
aws eks update-kubeconfig --name kcd-texas-student-NN --region us-east-2

# 4. Verify the cluster
kubectl get nodes
# Expected: 3 nodes, all STATUS=Ready, t3.xlarge each

kubectl get ns argocd kyverno monitoring backstage apps sample-app
# Expected: all 6 namespaces, STATUS=Active

# 5. Clone the workshop repo
git clone https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git ~/kcd-texas-workshop
cd ~/kcd-texas-workshop

# 6. Start Claude Code in that directory
claude
```

---

## Phase 1 — Bootstrap ArgoCD + app-of-apps (~20 min)

### Goal

Install ArgoCD via Helm into the `argocd` namespace, then `kubectl apply`
`gitops/bootstrap/app-of-apps.yaml`. ArgoCD picks up the root Application,
discovers the five child Applications at `gitops/apps/`, and begins syncing
them.

### Inputs

- `kubectl` configured for the student's cluster (preflight step 3-4)
- Working directory is `~/kcd-texas-workshop` (preflight step 5)
- Internet access from the cluster to GitHub + Helm chart repos (default for the workshop EKS clusters)

### The invocation

```
/workshop-phase 1
```

### What Claude does

1. Touches `.workshop-active` so the stop hook holds it on-phase
2. Reads `spec/WORKSHOP-BUILD-SPEC.md` (this file, Phase 1 section)
3. Reads `.claude/skills/argocd-patterns.md` (correct chart version, correct values path, sync wave conventions)
4. Reads `gitops/bootstrap/app-of-apps.yaml` (the root Application to apply)
5. Lists `gitops/apps/` to identify the 5 child Applications it should see
6. Runs:
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update
   helm install argocd argo/argo-cd \
     --namespace argocd \
     --version 9.5.11 \
     --set 'configs.cm.timeout\.reconciliation=30s' \
     --set controller.metrics.enabled=true \
     --set server.metrics.enabled=true \
     --set repoServer.metrics.enabled=true \
     --wait --timeout=10m

   # Chart 9.5.11 deploys ArgoCD v3.3.9 (which matches the pre-pulled image).
   # Newer 9.5.x patches (9.5.12+) deploy v3.4.x; using them is fine but the
   # pre-pull cache won't help and first-install time will be ~30s slower.
   ```
7. Runs `kubectl apply -f gitops/bootstrap/app-of-apps.yaml`
8. Polls `kubectl get application -n argocd` every 30s until 5 child Applications appear
9. Emits `<promise>WORKSHOP_PHASE_1_DONE</promise>`

### Verify

```bash
# All four ArgoCD core pods are Running
kubectl get pods -n argocd
# Expected pods (all STATUS=Running, READY=1/1 or 2/2):
#   argocd-application-controller-0
#   argocd-applicationset-controller-*
#   argocd-notifications-controller-*
#   argocd-redis-*
#   argocd-repo-server-*
#   argocd-server-*

# Root app-of-apps is Synced and Healthy; children are at least Progressing
kubectl get application -n argocd
# Expected:
#   NAME                     SYNC STATUS   HEALTH STATUS
#   app-of-apps              Synced        Healthy
#   kyverno                  Synced        Healthy or Progressing
#   kyverno-policies         Synced        Healthy or Progressing
#   kube-prometheus-stack    Synced        Healthy or Progressing
#   argocd-servicemonitors   OutOfSync     Missing      <- expected; waits for kube-prom-stack CRDs
#   backstage                Synced        Healthy or Progressing
```

### Expected duration

- Helm install: 1-2 min (images pre-pulled)
- `kubectl apply` of app-of-apps: instant
- Children appear in `kubectl get application`: 30-60s
- Children reach Synced/Healthy: 2-5 min (Backstage is slowest due to Postgres init)

### Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `helm install` fails with "context deadline exceeded" | Cluster API throttling or slow image pull on a node without pre-pull | `helm uninstall argocd -n argocd` and retry; the pre-pull DaemonSet may still be pulling on a slow node |
| `argocd-server` pod stuck `ContainerCreating` for >2 min | Image pull (pre-pull may have missed the tag) | `kubectl describe pod -n argocd argocd-server-*` to see the actual image tag; if not pre-pulled, that's fine — it'll pull at install time |
| `kubectl apply` of app-of-apps returns "no matches for kind \"Application\"" | ArgoCD CRDs not registered yet | Wait 30s. The CRDs are installed by the Helm chart; race condition. |
| Root app-of-apps stays `Unknown` for >2 min | ArgoCD can't reach the workshop repo | The workshop repo is public — usually a transient DNS issue. `kubectl logs -n argocd deploy/argocd-repo-server` to see the actual error. |
| `argocd-servicemonitors` shows `OutOfSync` / `Missing` | **Expected** until `kube-prometheus-stack` finishes syncing and registers the `ServiceMonitor` CRD. Should auto-recover within 3 min. | Wait. If it doesn't recover after 5 min, hard-refresh the Application in the ArgoCD UI. |

### Scorecard fields to fill (Phase 1 row)

- AI time (wall clock min from prompt to verify-passing)
- Correction cycles (distinct corrective prompts you sent Claude)
- Toil reduced (1–10)
- Integration (1–10) — did the five child Applications auto-discover and start installing without intervention?
- Tour or DIY
- Notes (one line, optional)

---

## Phase 2 — Kyverno admission + 3 ClusterPolicies (~20 min)

### Goal

Watch the `kyverno` and `kyverno-policies` Applications (already discovered by
ArgoCD in Phase 1) finish syncing. Verify the admission controller is running
and that the three ClusterPolicies fire correctly — a non-compliant pod gets
rejected; a compliant one gets through.

### Inputs

- Phase 1 complete (ArgoCD running, child Applications progressing)

### The invocation

```
/workshop-phase 2
```

### What Claude does

1. Reads `.claude/skills/kyverno-policies.md` (namespace exclusion strategy, webhook map-vs-list correction, ServerSideApply note)
2. Reads `gitops/apps/kyverno.yaml`, `gitops/apps/kyverno-policies.yaml`, and the three ClusterPolicy files under `gitops/manifests/kyverno-policies/`
3. Polls `kubectl get application kyverno -n argocd` until `Synced/Healthy`
4. Polls `kubectl get application kyverno-policies -n argocd` until `Synced/Healthy`
5. Runs the verification block below
6. Emits `<promise>WORKSHOP_PHASE_2_DONE</promise>`

### Verify

```bash
# Both Kyverno Applications are Synced and Healthy
kubectl get application kyverno kyverno-policies -n argocd
# Expected:
#   kyverno            Synced  Healthy
#   kyverno-policies   Synced  Healthy

# Kyverno controllers are Running
kubectl get pods -n kyverno
# Expected (all STATUS=Running):
#   kyverno-admission-controller-*
#   kyverno-background-controller-*
#   kyverno-cleanup-controller-*
#   kyverno-reports-controller-*

# Three ClusterPolicies exist with ENFORCE action and READY=true
kubectl get clusterpolicy
# Expected:
#   NAME                       BACKGROUND   VALIDATE ACTION   READY   AGE
#   disallow-privileged        false        Enforce           true    1m
#   require-labels             false        Enforce           true    1m
#   require-resource-limits    false        Enforce           true    1m

# A non-compliant pod (no labels, no resource limits) is REJECTED in apps:
kubectl run test-bad --image=nginx -n apps
# Expected output (one or more of the policies fires):
#   Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
#     resource Pod/apps/test-bad was blocked due to the following policies:
#     require-labels: ...
#     require-resource-limits: ...

# A compliant pod (has app+team labels, has limits) is ACCEPTED in apps:
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-good
  namespace: apps
  labels:
    app: demo
    team: workshop
spec:
  containers:
    - name: app
      image: nginx
      resources:
        limits:
          cpu: 100m
          memory: 128Mi
EOF
# Expected: pod/test-good created

# Same compliant pod in apps-policies-excluded namespace (kube-system) is also ACCEPTED
# (proves the webhook exclusions work)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-system
  namespace: kube-system
spec:
  containers:
    - name: app
      image: nginx
EOF
# Expected: pod/test-system created (no policy violation because kube-system is excluded)

# Cleanup
kubectl delete pod test-good -n apps
kubectl delete pod test-system -n kube-system
```

### Expected duration

- Kyverno chart install (sync wave -5): 1-2 min
- ClusterPolicies sync (sync wave -4): <1 min after Kyverno is healthy
- Verification (the four pod create/reject tests): <1 min
- Total Phase 2 wall time: 3-5 min if Phase 1 just finished, 1-2 min if Phase 1 has been running for a while

### Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `kyverno` Application stays `Progressing` for >5 min | Webhook `namespaceSelector` validation failure | `kubectl logs -n kyverno deploy/kyverno-admission-controller --tail 50` — look for "namespaceSelector format" or similar. The skill file enforces map format; if Claude got it wrong, fix the Application's values. |
| `kyverno-policies` Application stays `OutOfSync` after a "policies applied" event | CRD annotation too large (>256KB) when not using ServerSideApply | The Application in `gitops/apps/kyverno-policies.yaml` already sets `ServerSideApply=true` in syncOptions. If somehow missing, add it and hard-refresh. |
| `kubectl get clusterpolicy` returns nothing | Policies sync is behind. Wait 60s. | Check `kubectl get application kyverno-policies -n argocd -o yaml` for sync errors. |
| `test-bad` pod is ACCEPTED instead of rejected | Webhook not firing (Kyverno still initializing) | Wait 30s; admission controller can take ~1 min to fully register webhooks after first install. |
| `test-good` pod is REJECTED (claims missing labels even though we set them) | Policy `match` clause doesn't target the right namespace | Check the policy: `match.any.resources.namespaces` should be `[apps]`. If it's empty or `[*]`, the policy is over-firing. |
| Pods in `kube-system` get rejected | Webhook exclusion is missing or wrong format | Check `gitops/apps/kyverno.yaml` values — `config.webhooks.namespaceSelector` should be a **map** (with `matchExpressions`) not a list. |

### Scorecard fields to fill (Phase 2 row)

- AI time, Correction cycles, Toil reduced (1–10)
- Integration (1–10) — **did the policy actually fire correctly?** Bad pod rejected, good pod accepted, system pod allowed. All three must hold.
- Tour or DIY, Notes

---

## Phase 3 — Observability: Prometheus + Grafana + ArgoCD scraping (~20 min)

### Goal

Wait for `kube-prometheus-stack` (sync wave 1) and `argocd-servicemonitors`
(sync wave 2) to finish syncing. Verify Grafana is reachable and that
Prometheus is actually scraping ArgoCD's metrics endpoints.

### Inputs

- Phases 1 and 2 complete

### The invocation

```
/workshop-phase 3
```

### What Claude does

1. Reads this spec's Phase 3 block
2. Reviews `gitops/apps/kube-prometheus-stack.yaml` (notes the
   `serviceMonitorSelectorNilUsesHelmValues: false` override) and
   `gitops/apps/argocd-servicemonitors.yaml` (notes sync wave 2)
3. Polls both Applications until `Synced/Healthy`
4. Runs the verification block below
5. Tells the student the exact `kubectl port-forward` command for Grafana
6. Emits `<promise>WORKSHOP_PHASE_3_DONE</promise>`

### Verify

```bash
# Both observability Applications are Synced and Healthy
kubectl get application kube-prometheus-stack argocd-servicemonitors -n argocd
# Expected:
#   kube-prometheus-stack    Synced  Healthy
#   argocd-servicemonitors   Synced  Healthy

# All Prometheus + Grafana + node-exporter + kube-state-metrics pods are Running
kubectl get pods -n monitoring
# Expected (all STATUS=Running):
#   kube-prometheus-stack-grafana-*
#   kube-prometheus-stack-kube-state-metrics-*
#   kube-prometheus-stack-operator-*
#   kube-prometheus-stack-prometheus-node-exporter-*  (one per node, so 3)
#   prometheus-kube-prometheus-stack-prometheus-0  (StatefulSet)

# ServiceMonitors exist for ArgoCD
kubectl get servicemonitor -n argocd
# Expected:
#   argocd-application-controller   <minutes>
#   argocd-repo-server              <minutes>
#   argocd-server                   <minutes>

# Prometheus is actually scraping ArgoCD targets
# (port-forward Prometheus and check /api/v1/targets)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.scrapePool | contains("argocd")) | "\(.scrapePool) \(.health)"'
# Expected: 3 lines, one per argocd ServiceMonitor, all "up"
#   argocd/argocd-application-controller/0 up
#   argocd/argocd-repo-server/0 up
#   argocd/argocd-server/0 up
kill $PF_PID

# Open Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Browser: http://localhost:3000  (admin / kcd-texas)
# Click Dashboards -> Browse -> "Kubernetes / Compute Resources / Cluster"
# Expected: graphs are populated with cluster CPU + memory utilization.
# Click Explore -> Prometheus -> query `argocd_app_info` -> Run Query
# Expected: non-empty result set, one row per ArgoCD Application.
```

### Expected duration

- `kube-prometheus-stack` sync (sync wave 1): 2-4 min (largest install of the workshop)
- `argocd-servicemonitors` sync (sync wave 2): <1 min after wave 1
- Prometheus targets become "up": 30-60s after the ServiceMonitors are created
- Verification: 2-3 min including Grafana exploration

### Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `prometheus-*-0` StatefulSet pod stuck `Pending` for >2 min | No PVC / storage class issue | `kubectl describe pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0` — should auto-resolve once `ebs-csi` provisions a volume. EBS CSI is an EKS addon and should be present. |
| Grafana login fails with "Invalid email or password" | Admin password not set | The chart sets `adminPassword: kcd-texas` from `gitops/apps/kube-prometheus-stack.yaml`. If somehow stripped, reset: `kubectl -n monitoring exec deploy/kube-prometheus-stack-grafana -- grafana-cli admin reset-admin-password kcd-texas` |
| Grafana dashboards show "No data" on every panel | Prometheus not scraping yet — wait 60s | Visit `http://localhost:9090/targets` (port-forward Prometheus) and check whether targets are "up". If a target is "down" with a connection refused error, the metrics Service exists but the pod doesn't expose `/metrics`. |
| ArgoCD ServiceMonitor targets show "down" | The ArgoCD metrics Services don't exist | This means Phase 1 didn't set `controller.metrics.enabled=true` / `server.metrics.enabled=true` / `repoServer.metrics.enabled=true`. Helm upgrade to add them: see the Phase 1 `helm install` command above. |
| ServiceMonitors exist but Prometheus ignores them | `serviceMonitorSelectorNilUsesHelmValues` is still `true` (default) | Fix in `gitops/apps/kube-prometheus-stack.yaml` values — set to `false` (already done in the reference manifest). |
| `kube-prometheus-stack` Application stays `Progressing` for >10 min | Slow image pulls (alertmanager wasn't disabled, perhaps) | Check `kubectl get pods -n monitoring -w` — usually a node pulling a chart-bundled image. Pre-pull covers Prometheus, Grafana, prometheus-operator; node-exporter and kube-state-metrics are pulled at install time. |

### Scorecard fields to fill (Phase 3 row)

- AI time, Correction cycles, Toil reduced (1–10)
- Integration (1–10) — **is Grafana actually showing cluster metrics, AND is Prometheus scraping ArgoCD's metrics endpoints?** Both must hold.
- Tour or DIY, Notes

---

## Phase 4 — Backstage portal (~20 min)

### Goal

Wait for `backstage` (sync wave 5) to finish syncing. Open the Backstage UI
and verify it renders the community image's default catalog.

### Inputs

- Phases 1-3 complete

### The invocation

```
/workshop-phase 4
```

### What Claude does

1. Reads `.claude/skills/backstage-templates.md` (CRITICAL VERSION WARNING about `createBackend()`, community image note)
2. Reviews `gitops/apps/backstage.yaml` (image is `roadiehq/community-backstage-image:1.50.4`)
3. Polls `kubectl get application backstage -n argocd` until `Synced/Healthy`
4. Runs the verification block below
5. Tells the student the port-forward command
6. Emits `<promise>WORKSHOP_PHASE_4_DONE</promise>` and `<promise>WORKSHOP_COMPLETE</promise>`
7. Removes `.workshop-active` so the stop hook stops gating

### Verify

```bash
# Backstage Application is Synced and Healthy
kubectl get application backstage -n argocd
# Expected:  backstage   Synced  Healthy

# Backstage pod is Running
kubectl get pods -n backstage
# Expected (all STATUS=Running):
#   backstage-* (the app pod, READY=1/1)
#   backstage-postgresql-0 (in-cluster Postgres, READY=1/1)

# Open Backstage
kubectl port-forward -n backstage svc/backstage 7007:7007
# Browser: http://localhost:7007
# Expected: Backstage UI loads, "Home" page renders, Catalog has 1+ demo entries
# from the community image's defaults.
```

### Expected duration

- `backstage` sync (sync wave 5): 2-4 min (Postgres init + image pull, even
  with pre-pull, takes longer than other components)
- Backstage app ready: 60-90s after Postgres is ready
- Verification: 1-2 min

### Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Backstage pod fails to start with `createServiceBuilder is not a function` (in logs) | The image was built against the legacy backend (pre-2024). The current chart will not run it. | This shouldn't happen with the workshop default image. If you swapped to a custom image, rebuild it with `createBackend()` from `@backstage/backend-defaults`. |
| Backstage pod stuck `CrashLoopBackOff`, logs show DB connection refused | Postgres pod isn't ready yet (race condition) | Wait. `kubectl get pod -n backstage backstage-postgresql-0` — when it's `Running` and `READY=1/1`, Backstage will recover. |
| `kubectl port-forward` works but `http://localhost:7007` shows blank page | First request triggers asset compilation in some image variants | Refresh after 10s. If still blank, `kubectl logs -n backstage deploy/backstage` for stack trace. |
| Catalog page is empty | The community image has a tiny default catalog; if it's completely empty, the ConfigMap mount may be missing | `kubectl describe pod -n backstage <pod>` — check volume mounts include the catalog. |

### Scorecard fields to fill (Phase 4 row)

- AI time, Correction cycles, Toil reduced (1–10)
- Integration (1–10) — **does Backstage actually run AND show a populated catalog?**
- Tour or DIY, Notes

---

## End-state snapshot

After all four phases complete, the cluster should look like this:

```bash
# Five workshop Applications all Synced/Healthy + the root
kubectl get application -n argocd
# NAME                     SYNC STATUS   HEALTH STATUS
# app-of-apps              Synced        Healthy
# argocd-servicemonitors   Synced        Healthy
# backstage                Synced        Healthy
# kube-prometheus-stack    Synced        Healthy
# kyverno                  Synced        Healthy
# kyverno-policies         Synced        Healthy

# Workshop namespaces are populated
kubectl get pods -A | awk '$1 ~ /^(argocd|kyverno|monitoring|backstage)$/ { print }' | wc -l
# Expected: ~15-20 pods total across the four workshop namespaces

# Kyverno is enforcing in apps namespace
kubectl get clusterpolicy
# 3 policies, all Enforce, all Ready

# Prometheus scraping ArgoCD
kubectl get servicemonitor -n argocd | wc -l
# 4 lines (header + 3 ServiceMonitors)

# Three URLs available via port-forward:
#   ArgoCD UI:   kubectl port-forward -n argocd svc/argocd-server 8080:80
#                http://localhost:8080  (admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
#   Grafana:     kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
#                http://localhost:3000  (admin / kcd-texas)
#   Backstage:   kubectl port-forward -n backstage svc/backstage 7007:7007
#                http://localhost:7007
```

---

## Known correction patterns (the kubeauto reference build's bugs, avoided here)

These are mistakes the kubeauto reference build (and our own pre-workshop review) hit.
The skill files in `.claude/skills/` encode the correct patterns. If you (Claude or
human) are about to do one of the things in the left column, stop and use the right
column instead.

| Anti-pattern | Correct pattern |
|---|---|
| ArgoCD `targetRevision: "7.8.*"` (chart 7.x maps to older ArgoCD 3.x) | Chart `9.5.*` for current ArgoCD 3.3.x |
| `configs.params.timeout.reconciliation` for the demo sync interval | `configs.cm."timeout.reconciliation"` — the former silently writes to the wrong ConfigMap and the setting is ignored |
| Kyverno webhook `namespaceSelector` as a YAML list | Map keyed by `matchExpressions` (or `matchLabels`); the chart 3.7+ schema requires a map |
| Kyverno policies Application without `ServerSideApply=true` | Include `ServerSideApply=true` — Kyverno's CRD `metadata.annotations.kubectl.kubernetes.io/last-applied-configuration` can exceed Kubernetes' 256KB limit on a fresh install |
| Backstage `createServiceBuilder()` / `@backstage/backend-common` (or any other legacy backend pattern) | `createBackend()` from `@backstage/backend-defaults` — legacy backend was removed in Backstage early-2025 releases |
| Backstage chart with no image specified | Set `backstage.image.repository` + `backstage.image.tag` — the chart has no default image; without an image set, the pod has no container to run |
| Backstage chart `appVersion: "1.9.1"` (or similar guess) | The chart has no `appVersion` field; image tag is the only version control |
| ArgoCD ServiceMonitors created during the Phase 1 Helm install (`serviceMonitor.enabled: true`) | Apply them at sync wave 2 via a separate `argocd-servicemonitors` Application — at Phase 1 install time the `monitoring.coreos.com/ServiceMonitor` CRD doesn't exist yet |
| Prometheus selects only ServiceMonitors with the Helm chart's release label (chart default) | Override `serviceMonitorSelectorNilUsesHelmValues: false` on kube-prometheus-stack so Prometheus auto-discovers all ServiceMonitors regardless of label |
| `kubectl` patch of the `aws-auth` ConfigMap to grant student kubectl access | `aws eks create-access-entry` + `aws eks associate-access-policy AmazonEKSClusterAdminPolicy` — the API path is idempotent and doesn't require kubectl reachability from the provisioner laptop |
| Pre-pull image tags pinned to versions that don't match what the chart actually deploys | Pre-pull tags must track `gitops/apps/*.yaml` chart pins; update both together |
| Falco deployed as a "Protect" control | Falco is **Detect**. The workshop drops it from scope; if students add it post-workshop, document that it sits in the Detect matrix per the Agentic Covenants framework, not the Protect matrix this workshop builds |
| OTel Collector included in the 4-phase scope | The reference build hit 3 correction cycles on OTel — chart 0.145 breaking changes, wrong image variant, DaemonSet service quirks. Dropped from workshop scope; can be added post-workshop |

---

## Skill files index

| Skill file | Phase | Encodes |
|---|---|---|
| `.claude/skills/argocd-patterns.md` | 1 | Chart version mapping (9.x → ArgoCD 3.3.x), `configs.cm` vs `configs.params` correction, annotation-based tracking default, RBAC subject format, sync wave conventions, AppProject scoping, common Common Mistakes section |
| `.claude/skills/kyverno-policies.md` | 2 | Namespace exclusion strategy (full list), webhook `namespaceSelector` map format, ClusterPolicy template (validate.failure.action=Enforce, background=true), policy interaction patterns, ServerSideApply note |
| `.claude/skills/backstage-templates.md` | 4 | CRITICAL: `createBackend()` is mandatory since Backstage 1.46+ (early 2025); legacy backend removed; image config in values.yaml (chart has no appVersion); static catalog patterns; community-image-vs-custom-build note |

No dedicated skill file for `kube-prometheus-stack` (Phase 3) — the chart is
well-documented upstream and this spec's Phase 3 block covers the workshop-
specific values (`adminPassword`, `alertmanager.enabled: false`,
`serviceMonitorSelectorNilUsesHelmValues: false`).

---

## Scorecard mapping

Each phase has a row in `scorecard/SCORECARD-TEMPLATE.md` and a column in the
presenter scorecard at `scorecard/PRESENTER-SCORECARD.md`. The student scorecard
captures 4 phases × 6 columns; the presenter scorecard captures 6 sub-component
rows × 3 dimensions (Install / Integration / Usability) plus cycles + AI time.

**Verify maps to Integration scoring:**
- Phase 1 Integration = "did the five child Applications auto-discover and start installing cleanly?"
- Phase 2 Integration = "did Kyverno actually reject a bad pod AND allow a good one, AND allow a system pod?"
- Phase 3 Integration = "is Grafana showing populated dashboards AND is Prometheus scraping ArgoCD?"
- Phase 4 Integration = "did Backstage start cleanly AND show a populated catalog?"

Score Install and Integration **independently**. AI can install Kyverno
cleanly (high Install) and still produce policies that don't fire correctly
(low Integration). The "Toil Reduced" column on the student scorecard
captures Install-side toil; the "Integration" column captures whether the
thing works end-to-end.

The wrap-up reflection captures the third dimension — Usability — once, at
the end of the workshop. "Could you actually deploy a service through this
platform tomorrow morning?"

---

## Manual walkthrough checklist (for presenter / test runner)

Use this on the morning of the workshop, or earlier as a dry-run validation.
Walk through each step on a single test cluster, verify the expected output
matches, capture timing.

- [ ] **Preflight** — cluster exists, kubectl works, six namespaces present, six pre-pulled images cached on each node
- [ ] **Phase 1.1** — `helm install argocd ...` exits 0 within 2 min
- [ ] **Phase 1.2** — `kubectl get pods -n argocd` shows 6 ArgoCD pods Running
- [ ] **Phase 1.3** — `kubectl apply -f gitops/bootstrap/app-of-apps.yaml` exits 0
- [ ] **Phase 1.4** — `kubectl get application -n argocd` shows root + 5 children within 1 min
- [ ] **Phase 2.1** — within 5 min, `kyverno` and `kyverno-policies` Applications both `Synced`/`Healthy`
- [ ] **Phase 2.2** — `kubectl get clusterpolicy` shows 3 policies, all `Enforce`/`true`
- [ ] **Phase 2.3** — `kubectl run test-bad --image=nginx -n apps` is **rejected** with policy violation message
- [ ] **Phase 2.4** — compliant pod manifest in `apps` is **accepted**
- [ ] **Phase 2.5** — non-compliant pod in `kube-system` is **accepted** (exclusion works)
- [ ] **Phase 3.1** — within 5 min, `kube-prometheus-stack` and `argocd-servicemonitors` both `Synced`/`Healthy`
- [ ] **Phase 3.2** — `kubectl get pods -n monitoring` shows Prom + Grafana + operator + node-exporter (3) + kube-state-metrics, all Running
- [ ] **Phase 3.3** — `kubectl get servicemonitor -n argocd` shows 3 entries
- [ ] **Phase 3.4** — Prometheus `/api/v1/targets` shows ArgoCD targets all `up`
- [ ] **Phase 3.5** — Grafana login works with `admin / kcd-texas`
- [ ] **Phase 3.6** — `Kubernetes / Compute Resources / Cluster` dashboard is populated
- [ ] **Phase 3.7** — query `argocd_app_info` in Explore returns rows
- [ ] **Phase 4.1** — within 5 min, `backstage` Application `Synced`/`Healthy`
- [ ] **Phase 4.2** — `kubectl get pods -n backstage` shows backstage and backstage-postgresql, both Running
- [ ] **Phase 4.3** — port-forward + browser to `http://localhost:7007` renders the Backstage Home
- [ ] **Phase 4.4** — Backstage Catalog has at least one entry from the community image default

Total wall time for a clean run: **15–30 minutes** of active build time after
the cluster preflight completes. The workshop budget of 90 min builds in
substantial buffer for explanations, debugging, and scoring discussion.

---

## Timing reference (from validated runs)

> The timing data below is filled in by the workshop maintainer after running
> a validated end-to-end walk-through. The kubeauto reference build's
> equivalent timing (3h 10m AI time across 27 components) is in
> `kubeauto-ai-day/spec/SCORECARD.md`. The condensed 4-phase workshop should
> see roughly 15-25 min of pure AI-build time, plus verification overhead.

| Phase | Run-1 wall time | Run-2 wall time | Notes |
|---|---|---|---|
| Phase 1 | _TBD_ | _TBD_ | |
| Phase 2 | _TBD_ | _TBD_ | |
| Phase 3 | _TBD_ | _TBD_ | |
| Phase 4 | _TBD_ | _TBD_ | |
| **Total** | _TBD_ | _TBD_ | |
