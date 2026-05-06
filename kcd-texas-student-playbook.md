# KCD Texas 2026 — Student Playbook

**Workshop:** "The 90-Minute IDP" • **Date:** May 15, 2026 • **Tool:** Claude Code

You walk in, your EKS cluster is already running, and in 90 minutes you'll have a working Internal Developer Platform on top of it: GitOps with ArgoCD, policy enforcement with Kyverno, observability with Prometheus + Grafana, and a developer portal with Backstage.

You don't type Kubernetes YAML. You **describe what you want to Claude Code**, paste the prompts below, run the verification command, and move on.

> **About versions.** The prompts say "current stable GA chart" instead of pinned chart numbers. We're not version-archaeology hobbyists; whatever Helm resolves on workshop day is what you'll deploy, and Claude knows the current chart values structure. The skill files loaded into your environment encode the conventions that don't change between minor versions (RBAC subject format, sync waves, namespace exclusion lists, the new-backend-system rule for Backstage).

---

## Before You Start (5 min)

**Your connection card lists what you need:**

- AWS access key + secret (for your IAM user)
- Cluster name (`kcd-texas-student-NN`)
- A Git repo URL — your **per-student workshop repo**, pre-created with a `gitops/apps/` skeleton directory. ArgoCD will pull from this repo. You'll commit and push to it during the workshop.
- The Backstage workshop image (e.g. `<registry>/kcd-texas-backstage:<tag>`) — needed in Phase 4.

**On your laptop, in your terminal:**

```bash
# 1. Configure AWS with the keys on your connection card
aws configure
# AWS Access Key ID:     (from card)
# AWS Secret Access Key: (from card)
# Default region:        us-east-2
# Default output format: json

# 2. Connect kubectl to your cluster
aws eks update-kubeconfig --name kcd-texas-student-NN --region us-east-2

# 3. Verify the cluster is alive
kubectl get nodes
# Expected: 3 nodes, all Ready, ~2 minutes old or older

# 4. Verify the workshop namespaces are pre-created
kubectl get ns argocd kyverno monitoring backstage apps sample-app
# Expected: all 6 namespaces, status Active

# 5. Clone your per-student workshop repo (URL is on your connection card)
git clone <your-repo-url> ~/kcd-texas-workshop
cd ~/kcd-texas-workshop

# 6. Start Claude Code in that directory
claude
```

If `kubectl get nodes` fails or shows fewer than 3 nodes, **raise your hand**. We have spare clusters.

**How this playbook works.** Each of the four phases gives you:

1. **Goal** — what you're building
2. **Prompt** — copy-paste into Claude Code
3. **Verify** — one command that proves it worked
4. **If broken** — the most common failure and the fix
5. **Scorecard** — record your numbers (you'll fill in the scorecard at the end)

The prompts assume Claude Code has the workshop skill files loaded (`argocd-patterns.md`, `kyverno-policies.md`, `backstage-templates.md`). They were dropped into your environment during cluster provisioning.

**About Git in the loop.** From Phase 2 onward, Claude Code will write each Application manifest into `gitops/apps/` in your local clone and `git commit && git push` to your workshop repo. ArgoCD polls the repo every 30 seconds and syncs the cluster to match. Don't be surprised when you see commits and pushes happening — that's the GitOps loop doing its job. If a `git push` fails for credential reasons, your repo's deploy key or PAT isn't set up; raise your hand.

---

## Phase 1 — GitOps with ArgoCD (~20 min)

### Goal

Install ArgoCD into the `argocd` namespace via Helm, then bootstrap the **app-of-apps** pattern so a single root Application manages every other component you'll install today. After this phase, every *component you install* flows through Git — you'll still use `kubectl` for inspection and ad-hoc test pods.

### Prompt

> Install ArgoCD using the current stable GA Helm chart `argo-cd` from `https://argoproj.github.io/argo-helm` into the `argocd` namespace. Set `configs.cm."timeout.reconciliation"` to `30s` so demo syncs are fast (this writes to the `argocd-cm` ConfigMap — `configs.params` is a different sibling section, don't use that path). Then create an app-of-apps root Application named `root` in the `argocd` namespace pointing to the `gitops/apps/` directory of my workshop repo on the `main` branch, with automated sync, prune, and selfHeal enabled. Write a quick test that asserts the ArgoCD server pod is `Running` and the `root` Application's status is `Synced` and `Healthy`. Run the test, fix until it passes, then stop.

### Verify

```bash
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller, argocd-redis,
# all in Running state

kubectl get application -n argocd
# Expected: NAME=root, SYNC STATUS=Synced, HEALTH STATUS=Healthy
```

### If Broken

| Symptom | Fix |
|---|---|
| `argocd-server` pod stuck `Pending` | Run `kubectl describe pod -n argocd <pod>` — usually image pull or missing PVC. Tell Claude: "the pod is Pending because <reason>, fix it." |
| `root` Application stuck `Progressing` and points to a private repo | Add a repo credential Secret. Tell Claude: "create a Secret named `repo-creds` in `argocd` namespace with type `repository`, repository URL <yours>, and a GitHub PAT, label it `argocd.argoproj.io/secret-type=repository`." |
| Helm install fails with "chart not found" | Helm repo isn't refreshed. Tell Claude: "run `helm repo update` first, then retry the install." |

### Scorecard for Phase 1

Record at the end:

- AI time (wall clock): __ min
- Correction cycles (how many times did you need to give Claude a corrective prompt?): __
- Toil reduced (1–10): __
- Notes: __

---

## Phase 2 — Policy with Kyverno (~20 min)

### Goal

Install Kyverno into the `kyverno` namespace as an ArgoCD Application (no `kubectl apply`). Then create three ClusterPolicies that enforce on the `apps` namespace only: pods must have `app` and `team` labels, pods must declare CPU and memory limits, and privileged containers are disallowed. System namespaces (`kube-system`, `argocd`, `monitoring`, `backstage`, `kyverno`) are excluded from enforcement.

### Prompt

> Add a Kyverno Application to my `gitops/apps/` directory using the current stable GA Helm chart `kyverno` from `https://kyverno.github.io/kyverno/` into the `kyverno` namespace, sync wave -5. Then add a separate Application `kyverno-policies` (sync wave -4) that applies three ClusterPolicies in **enforce** mode, scoped to match Pods only in namespace `apps`, excluding `kube-system, kube-public, kube-node-lease, kyverno, argocd, monitoring, backstage, sample-app`:
>
> 1. `require-labels` — pods must have non-empty labels `app` and `team`
> 2. `require-resource-limits` — pods must set `resources.limits.cpu` and `resources.limits.memory`
> 3. `disallow-privileged` — `securityContext.privileged` must not be `true`
>
> Use `ServerSideApply=true` on the policies Application. Write a test that creates a pod in `apps` without limits, expects rejection at admission, and a pod in `kube-system` with the same shape that should be allowed. Run, fix, stop.

> **Heads-up:** Current Kyverno releases auto-generate Kubernetes-native ValidatingAdmissionPolicies alongside your ClusterPolicies on EKS 1.30+. You'll see VAPs appear in `kubectl get validatingadmissionpolicy` — that's expected, not a bug. If you don't want them, add `--generateValidatingAdmissionPolicy=false` to the admission controller args via Helm values.

### Verify

```bash
kubectl get pods -n kyverno
# Expected: kyverno admission, background, cleanup, reports controllers all Running

# Try to create a non-compliant pod in apps — admission should reject:
kubectl run test-bad --image=nginx -n apps
# Expected: error from server: admission webhook "validate.kyverno.svc-fail"
# denied the request: ... require-resource-limits ...

# Create a compliant pod — should succeed:
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-good
  namespace: apps
  labels: { app: demo, team: workshop }
spec:
  containers:
  - name: app
    image: nginx
    resources:
      limits: { cpu: 100m, memory: 128Mi }
EOF
# Expected: pod/test-good created
```

### If Broken

| Symptom | Fix |
|---|---|
| Kyverno pods crash-looping with webhook config errors | The webhook `namespaceSelector` must be a map, not a list, in current chart versions. Tell Claude: "the webhook namespaceSelector is the wrong format, it should be a map keyed by `matchExpressions` or `matchLabels`, fix it." |
| ArgoCD reports "annotation too large" on the policies Application | CRDs are large. Tell Claude: "set `ServerSideApply=true` on the Application's syncOptions." |
| ArgoCD shows the policies as `OutOfSync` even after applying server-side | Stale ArgoCD cache. In the ArgoCD UI, hit **Hard Refresh** on the application. |
| Compliant pod also gets rejected | Your namespace exclusion list is wrong. Re-check that `apps` is *not* in the excluded list and the policy `match` block targets `namespaces: [apps]`. |

### Scorecard for Phase 2

- AI time: __ min  •  Corrections: __  •  Toil reduced: __ /10  •  Notes: __

---

## Phase 3 — Observability with kube-prometheus-stack (~20 min)

### Goal

Install `kube-prometheus-stack` (Prometheus + Grafana + node-exporter + kube-state-metrics + alertmanager, all in one chart) into the `monitoring` namespace as an ArgoCD Application. Open Grafana and confirm cluster metrics are flowing.

### Prompt

> Add a `prometheus` Application to `gitops/apps/` using the current stable GA Helm chart `kube-prometheus-stack` from `https://prometheus-community.github.io/helm-charts/`, into namespace `monitoring`, sync wave 1. Set Grafana's admin password to `kcd-texas` for the workshop and enable the default dashboards. Write a test that asserts the Prometheus and Grafana pods are `Running` and that querying Prometheus's `/api/v1/query?query=up` over `port-forward` returns a non-empty result list. Run, fix, stop.

### Verify

```bash
kubectl get pods -n monitoring
# Expected: prometheus-kube-prometheus-stack-prometheus-0,
# kube-prometheus-stack-grafana-*, kube-state-metrics, node-exporter (one per node),
# alertmanager. All Running.

# Open Grafana in your browser:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# In another terminal or browser tab: http://localhost:3000
# User: admin  •  Password: kcd-texas
# Click Dashboards → Browse → "Kubernetes / Compute Resources / Cluster" — graphs should be populated.
```

### If Broken

| Symptom | Fix |
|---|---|
| `prometheus-*-0` stuck `Pending` | Storage class issue. Tell Claude: "set `prometheus.prometheusSpec.storageSpec` to use the cluster's default storage class, or use `emptyDir` for the workshop." |
| Grafana shows "no data" on every panel | Prometheus isn't scraping yet — wait 60s. If still empty, check `kubectl get servicemonitor -n monitoring` shows endpoints. |
| Helm install hangs > 3 min | Prometheus + Grafana images are pre-pulled, but `node-exporter`, `kube-state-metrics`, and `alertmanager` may pull at install time (~60s). If still hung after 3 min, tell Claude to split the install: apply the CRDs first, then install the chart with `--skip-crds`. |

### Scorecard for Phase 3

- AI time: __ min  •  Corrections: __  •  Toil reduced: __ /10  •  Notes: __

---

## Phase 4 — Developer Portal with Backstage (~20 min)

### Goal

Install Backstage into the `backstage` namespace as an ArgoCD Application with a static (ConfigMap-backed) catalog and **one** software template called "Deploy a new service" that creates a namespace-scoped Deployment + Service + Kyverno-compliant pod spec. Open Backstage and run the template.

**Critical:** Backstage's old (pre-2024) backend system is deprecated and won't start with current Helm charts. Your skill file forces the new `createBackend()` API. If Claude generates anything referring to `createServiceBuilder()` or `@backstage/backend-common`, that's the legacy system — reject it. Also note: the Backstage chart has no default image — you must point it at a Backstage image (the workshop publishes one; the tag is on your connection card).

### Prompt

> Add a `backstage` Application to `gitops/apps/` using the current stable GA Helm chart `backstage` from `https://backstage.github.io/charts` into namespace `backstage`, sync wave 5. The chart has no default image — set `backstage.image.repository` and `backstage.image.tag` to the workshop's pre-built Backstage image (the value is on your connection card; if blank, use `roadiehq/community-backstage-image` with a recent stable tag). Internally the image must use the **new backend system** (`createBackend()` from `@backstage/backend-defaults`) — if the workshop image was built with the legacy `createServiceBuilder` / `@backstage/backend-common`, it will not start; ask a TA. Configure a static catalog via a ConfigMap mounted at `/app/catalog` with a single Component for the workshop sample app. Add one software template called `deploy-service` whose skeleton **deploys into the `apps` namespace** and produces: a Deployment with `httpGet` liveness and readiness probes, a Service, labels `app` and `team`, and CPU + memory limits — so the result passes the Kyverno policies from Phase 2. Write a test that asserts the Backstage pod is `Running` and the catalog HTTP endpoint returns the sample component. Run, fix, stop.

### Verify

```bash
kubectl get pods -n backstage
# Expected: backstage-* pod Running

kubectl port-forward -n backstage svc/backstage 7007:7007
# Open http://localhost:7007 in your browser.
# Click Create → "Deploy a new service" → fill in name="hello", team="workshop".
# Click "Create" — Backstage generates the manifests; ArgoCD picks them up and deploys.

kubectl get pods -n apps -l app=hello
# Expected: hello-* pod Running and passes Kyverno (it has labels, limits, probes)
```

### If Broken

| Symptom | Fix |
|---|---|
| Backstage pod fails to start with `createServiceBuilder is not a function` | Claude generated legacy backend code. Tell it: "you used the legacy backend system. Rewrite using `createBackend()` from `@backstage/backend-defaults` per the skill file. Do not use `@backstage/backend-common`." |
| Template runs but the new pod is rejected by Kyverno | Skeleton missed labels, limits, or probes. Open the template skeleton, check that `metadata.labels.app`, `metadata.labels.team`, `resources.limits`, and both `livenessProbe.httpGet` + `readinessProbe.httpGet` are present. |
| Catalog page is empty | ConfigMap not mounted or path wrong. `kubectl describe pod -n backstage <pod>` and look at volume mounts. |

### Scorecard for Phase 4

- AI time: __ min  •  Corrections: __  •  Toil reduced: __ /10  •  Notes: __

---

## Wrap-Up (5 min)

Total your scorecard:

| Phase | AI time | Corrections | Toil reduced (1–10) |
|---|---:|---:|---:|
| 1 — ArgoCD | __ | __ | __ |
| 2 — Kyverno | __ | __ | __ |
| 3 — Prometheus + Grafana | __ | __ | __ |
| 4 — Backstage | __ | __ | __ |
| **Total / Average** | __ | __ | __ |

For comparison, the reference build (a single experienced engineer running this same stack end-to-end without time pressure) took **31 minutes of AI time** across these four components and saw a **73.8% net toil reduction** vs. doing it by hand. Don't worry if your numbers are different — you're working under workshop pacing, not a private overnight build.

### What You Have Now

- An EKS cluster running an Internal Developer Platform that mirrors what most platform teams spend weeks setting up
- GitOps reconciliation: any change to your Git repo flows through ArgoCD into the cluster
- Admission-time policy: bad pods are rejected before they ever run
- Cluster observability: Prometheus is scraping, Grafana is graphing
- A developer portal that turns "deploy a new service" into a form

### Where to Take It Next

Outside this room, on your own time, you can extend the same pattern to:
- Add Falco for runtime threat detection
- Add cert-manager + an OIDC issuer for TLS
- Add ExternalSecrets pulling from AWS Secrets Manager
- Add a second Backstage template for "create a new namespace"
- Wire OpenTelemetry traces through the OTel Collector

The reference build at [github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day) shows the full 7-phase version of what you built today.

### Cluster Teardown

You don't need to clean up — the workshop infrastructure is destroyed shortly after the session ends. Save anything you want to keep (manifests, Grafana screenshots) before you walk out.

---

## If Something Is Really Stuck

If you've burned more than 5 minutes on a single failure and the "If broken" hints didn't help:

1. Raise your hand — a TA will come over.
2. If you're past Phase 2 and your cluster is genuinely broken, we have **spare clusters**. Your TA can move you to one and you can pick up from where the rest of the room is.
3. Don't try to fix infrastructure from scratch. The point of the workshop is to use Claude Code on a working substrate; lost time on the substrate is wasted time.
