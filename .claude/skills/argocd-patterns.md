# ArgoCD Patterns Skill (chart 9.x, ArgoCD 3.x line)

Use this skill **before generating any ArgoCD manifest.** Most tutorials and blog posts reference patterns from chart 5.x–7.x (ArgoCD 2.x). The current chart line is **9.x**, which produces ArgoCD **v3.x**. The differences matter.

## Critical version pins

| Thing | Current GA at workshop time |
|---|---|
| Helm chart name | `argo-cd` |
| Helm repo | `https://argoproj.github.io/argo-helm` |
| Chart version | `9.5.x` (current GA in the 9.x line) |
| ArgoCD app version | `v3.4.x` |
| Default reconciliation timeout | `120s` (workshop overrides to `30s`) |
| Resource tracking method | annotation-based (3.x default; do not set to `label`) |

`argo/argo-cd 7.x` still exists but is ArgoCD v2.14, feature-frozen. Don't pin to 7.x unless the user explicitly asks.

## Pattern 1 — Helm installation values for the workshop

The workshop installs ArgoCD via `helm install` (not via Application — ArgoCD is the thing that runs Applications). The values you generate should produce something equivalent to:

```bash
helm install argocd argo/argo-cd -n argocd --create-namespace -f - <<'YAML'
server:
  extraArgs:
    - --insecure          # Workshop: TLS terminates at port-forward
configs:
  cm:
    timeout.reconciliation: "30s"   # 30s for fast demo syncs (default is 120s)
  # Do NOT set configs.params.timeout.reconciliation — wrong path; the timeout
  # lives in argocd-cm, not argocd-cmd-params-cm.
  # Annotation-based resource tracking is the DEFAULT in 3.x. Do NOT set
  # application.resourceTrackingMethod: "label" — that's legacy 2.x behavior.
YAML
```

**Verified:** chart 9.5.13 has `timeout.reconciliation` under `configs.cm` (writes to `argocd-cm` ConfigMap). `helm template` confirms the rendered ConfigMap contains the override.

## Pattern 2 — app-of-apps bootstrap Application

This is **not** installed by the chart — it's a `kubectl apply` after ArgoCD is up. Match the structure of `gitops/bootstrap/app-of-apps.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # Clean up child apps on delete
spec:
  project: default
  source:
    repoURL: https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git
    targetRevision: main
    path: gitops/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

Notes:
- **No sync-wave on the bootstrap itself** — it's the top of the tree. Sync waves are on the *child* Applications in `gitops/apps/`.
- **`targetRevision: main`** — the workshop reads from `main` (not `staging`). `staging` is the working branch; `main` is the canonical version ArgoCD watches.
- **Finalizer** — `resources-finalizer.argocd.argoproj.io` ensures `kubectl delete application app-of-apps` actually cleans up the platform.
- **Retry policy** — exponential backoff because Phase 1 reconciles may race CRDs.

## Pattern 3 — Sync waves (the workshop's actual ordering)

The pre-committed manifests use these waves (verified against `gitops/apps/`):

| Component | Wave | Why this wave |
|---|---|---|
| `kyverno` (chart install) | `-5` | First — admission controller must exist before policies |
| `kyverno-policies` | `-4` | After Kyverno controller; CRDs must exist |
| `kube-prometheus-stack` | `1` | After admission policies are enforcing; needs them to allow its pods through |
| `backstage` | `5` | Last — depends on having observability + policies in place |

Annotation form:

```yaml
metadata:
  name: kyverno
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"   # String, not int
```

Wave values are **strings**, not integers. Lower runs first. Apps in the same wave run in parallel.

**Most common Claude failure:** generating four child Applications with no sync-wave annotations. Result: parallel install, Kyverno policies race the Kyverno controller, policy CRDs aren't ready when policies try to apply, ArgoCD shows the policy Application as `OutOfSync` for ~3 minutes. Adding waves fixes it.

## Pattern 4 — syncOptions for charts with large CRDs

The Prometheus operator's CRDs exceed Kubernetes's annotation size limit (256 KB). Without `ServerSideApply=true`, ArgoCD's `kubectl.kubernetes.io/last-applied-configuration` annotation gets too large, and the CRDs flip `OutOfSync` every reconcile.

Always include `ServerSideApply=true` for charts with large CRDs:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

Required for: `kube-prometheus-stack`, `kyverno`, `backstage`. Harmless to add to all charts.

## Pattern 5 — Helm-chart Application structure

When deploying a Helm chart via Application (Phases 2–4):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <component>
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "<N>"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    chart: <chart-name>                    # Just the chart, no slash
    repoURL: https://<chart-repo-url>      # The HTTPS repo URL
    targetRevision: "<chart-version>"      # Pinned version
    helm:
      valuesObject:                        # Typed YAML, not a multi-line string
        # ...chart-specific values
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

**Do not generate:**
- `helm.values: |` as a multi-line YAML string — deprecated. Use `helm.valuesObject:`.
- `chart: argoproj/argo-cd` (with a slash) — `chart:` takes only the chart name; `repoURL:` is the registry.

## Common failure modes

| What you see | Likely cause | Fix |
|---|---|---|
| Application stuck `Progressing` | Resource references a CRD that doesn't exist yet | Add sync-wave so the CRD installs first |
| `last-applied-configuration: too long` on CRD apply | No ServerSideApply for a chart with large CRDs | Add `ServerSideApply=true` to syncOptions |
| Resources created in wrong namespace | `destination.namespace` mismatched with manifest's `metadata.namespace` | Match them, or omit `metadata.namespace` and let destination apply |
| Application `OutOfSync` every reconcile | Helm chart's controller mutates managed resources (e.g., setting status) | Either accept with `selfHeal: true`, or add `ignoreDifferences` for the mutating fields |
| `argocd app list` shows everything healthy but no pods exist | Application is `Synced` against an empty path | Verify `source.path` and `source.repoURL` |

## Verify commands

```bash
# Core ArgoCD pods
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller-0, argocd-redis — all Running

# Applications discovered
kubectl get application -n argocd

# A specific Application's sync + health status
kubectl get application <name> -n argocd -o jsonpath='{.status.sync.status}/{.status.health.status}'

# Initial admin password (workshop)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d ; echo
```
