# ArgoCD Patterns Skill — KCD Texas 2026 Workshop

Adapted from `kubeauto-ai-day/.claude/skills/argocd-patterns.md` for the
90-minute workshop. Same patterns, but updated chart pins and one critical
values-path correction.

This skill encodes correct patterns for ArgoCD 3.2+. The entire ArgoCD 2.x line
is END OF LIFE. Most tutorials, blog posts, and Stack Overflow answers reference
2.x patterns that will produce broken or deprecated configurations.

**When in doubt, assume a pattern you recall is from 2.x and verify it here.**

---

## Correct Patterns

### Helm Chart Installation (3.x)

ArgoCD 3.x uses the `argo-cd` Helm chart from the official OCI registry.

```yaml
# ArgoCD 3.2+ Helm values
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: default
  source:
    chart: argo-cd
    repoURL: https://argoproj.github.io/argo-helm
    targetRevision: "9.5.*"    # 9.x chart = ArgoCD 3.3.x (as of May 2026).
                                # Chart 7.x maps to older ArgoCD 3.x; do not use.
    helm:
      valuesObject:
        # 3.x: annotation-based tracking is the DEFAULT
        # Do NOT set tracking method to "label" — that is legacy 2.x behavior
        server:
          extraArgs:
            - --insecure  # If terminated at LB/ingress
        configs:
          cm:
            # 30-second reconciliation for demo purposes (default is 3 minutes).
            # CRITICAL: this lives under configs.cm (argocd-cm ConfigMap), NOT
            # configs.params (argocd-cmd-params-cm).  Using configs.params here
            # silently writes to the wrong ConfigMap and the setting is ignored.
            timeout.reconciliation: "30s"
            # Self-heal: auto-correct drift
            application.resourceTrackingMethod: "annotation"  # default in 3.x, explicit for clarity
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Annotation-Based Tracking (Default in 3.x)

ArgoCD 3.x defaults to annotation-based resource tracking. It uses the
`argocd.argoproj.io/tracking-id` annotation on managed resources.

```yaml
# You do NOT need to set this — it is the default in 3.x
# Shown for awareness only
configs:
  cm:
    application.resourceTrackingMethod: "annotation"
```

Do NOT set `application.resourceTrackingMethod: "label"` — that is the legacy
2.x default and causes issues with resources that have label length limits.

### RBAC Configuration (3.x Subject Format)

ArgoCD 3.x changed the RBAC subject format for Dex/OIDC users and groups.
The prefix format now uses the SSO provider name.

```yaml
configs:
  rbac:
    policy.csv: |
      # 3.x format: role:<role-name> for built-in roles
      # 3.x format: <sso-provider>:<group-or-user> for SSO subjects

      # Grant admin to a specific OIDC group
      g, oidc:platform-admins, role:admin

      # Grant read-only to all authenticated users
      p, role:readonly, applications, get, */*, allow
      p, role:readonly, applications, list, */*, allow
      g, oidc:authenticated, role:readonly

    # Default policy for authenticated users with no matching rule
    policy.default: role:readonly

    # Scopes to request from OIDC provider
    scopes: "[groups, email]"
```

**2.x used different subject prefixes.** If you see examples with bare group
names or `sso:` prefix, those are 2.x patterns.

### App-of-Apps Pattern

The root application bootstraps all other applications via sync waves.

```yaml
# Root app-of-apps application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
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
```

### Sync Waves

Sync waves control deployment ordering. Lower numbers deploy first.

```yaml
# gitops/apps/namespaces.yaml — wave -10 (first)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: namespaces
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: default
  source:
    repoURL: https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git
    targetRevision: main
    path: gitops/base/namespaces
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

---
# gitops/apps/kyverno.yaml — wave -5 (before apps that need policies)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
# ...

---
# gitops/apps/sample-app.yaml — wave 5 (after platform components)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
# ...
```

**Recommended wave ordering for this project:**
- Wave -10: Namespaces, CRDs
- Wave -5: Security stack (Kyverno, Falco, ESO), ArgoCD self-manage
- Wave 0: Observability (Prometheus, Grafana, OTel)
- Wave 3: Platform services (Backstage)
- Wave 5: Application workloads (sample Flask app)

### 30-Second Demo Sync Interval

For the workshop demo, set a 30-second reconciliation interval so changes appear fast.

```yaml
configs:
  cm:
    timeout.reconciliation: "30s"
```

**CRITICAL:** the path is `configs.cm.timeout.reconciliation`, NOT
`configs.params.timeout.reconciliation`. The former writes to the `argocd-cm`
ConfigMap (correct, controller reads from here). The latter writes to
`argocd-cmd-params-cm` (wrong, silently ignored for this setting).

**Do NOT use 30s in production.** The default 3-minute interval is appropriate
for real clusters. This is a workshop demo optimization only.

### Self-Heal Policy

Self-heal automatically reverts manual changes (drift) to match Git state.

```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources deleted from Git
    selfHeal: true   # Revert manual changes to match Git
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### ApplicationSet for Multi-Environment (Optional)

If generating apps from a directory structure:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-components
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git
        revision: main
        directories:
          - path: gitops/components/*
  template:
    metadata:
      name: "{{path.basename}}"
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git
        targetRevision: main
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## Agentic Covenants framing

ArgoCD is a server-side enforcement control in the **Agentic Covenants** matrix
(see `github.com/peopleforrester/agentic-covenants`). Specifically:

| Concern row | How ArgoCD covers it |
|-------------|---------------------|
| **Approval gating** (server-side) | All changes flow Git → ArgoCD reconcile. No `kubectl apply` after Phase 1 bootstrap. Self-heal auto-reverts manual drift. Pre-committed reference manifests in `gitops/apps/` are the source of truth. |
| **Blast radius** (server-side) | Sync waves order destructive operations. `prune: true` removes resources deleted from Git. Retry policy with bounded backoff prevents runaway reconcile storms. |

The workshop is a worked example of one column of that matrix. Don't dwell on
this in the skill; it's framing for what students are touring.

---

### ArgoCD Project Scoping

Restrict what the `default` project can deploy to, and create a platform project.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform infrastructure components
  sourceRepos:
    - "https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git"
    - "https://argoproj.github.io/argo-helm"
    - "https://charts.jetstack.io"
    - "https://kyverno.github.io/kyverno"
    - "https://prometheus-community.github.io/helm-charts"
    - "https://backstage.github.io/charts"
    - "https://falcosecurity.github.io/charts"
  destinations:
    - namespace: "*"
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: "*"
      kind: "*"
```

---

## Common Mistakes

### CRITICAL: Use the current chart version for ArgoCD 3.3.x

```yaml
# WRONG — chart version 5.x and 6.x map to ArgoCD 2.x (EOL)
targetRevision: "5.51.6"
targetRevision: "6.7.3"

# STALE (kubeauto reference build used these) — chart 7.x maps to older ArgoCD 3.x
targetRevision: "7.8.*"

# CORRECT (as of May 2026) — chart 9.x maps to ArgoCD 3.3.x
targetRevision: "9.5.*"
```

The chart-to-app mapping moves over time. Check
[argo-helm releases](https://github.com/argoproj/argo-helm/releases) for the
current stable chart that maps to the ArgoCD release you want.

### CRITICAL: Do NOT use label-based tracking

```yaml
# WRONG — label-based tracking is legacy 2.x default
configs:
  cm:
    application.resourceTrackingMethod: "label"

# CORRECT — annotation-based tracking is the 3.x default
# Simply do not set it, or explicitly:
configs:
  cm:
    application.resourceTrackingMethod: "annotation"
```

### CRITICAL: Do NOT use 2.x RBAC subject format

```yaml
# WRONG — 2.x subject format
g, my-github-org:my-team, role:admin

# CORRECT — 3.x subject format with SSO provider prefix
g, oidc:my-github-org:my-team, role:admin
```

### Do NOT use deprecated `argocd-cm` ConfigMap keys directly

In 3.x, most configuration has moved to Helm values under `configs.params` and
`configs.cm`. Do not create raw ConfigMaps.

```yaml
# WRONG — raw ConfigMap manipulation
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
data:
  timeout.reconciliation: "30s"

# CORRECT — set via Helm values
configs:
  params:
    timeout.reconciliation: "30s"
```

### Do NOT put Application resources outside the argocd namespace

```yaml
# WRONG
metadata:
  name: my-app
  namespace: default  # Applications must live in the argocd namespace

# CORRECT
metadata:
  name: my-app
  namespace: argocd
```

### Do NOT forget finalizers for pruning

Without the finalizer, deleting an Application does not clean up deployed resources.

```yaml
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
```

### Do NOT set sync interval below 30s in production

```yaml
# WRONG for production (causes excessive API calls)
timeout.reconciliation: "5s"

# ACCEPTABLE for demo only
timeout.reconciliation: "30s"

# CORRECT for production
timeout.reconciliation: "180s"  # default
```

---

## Validation Commands

```bash
# Verify ArgoCD version is 3.x
kubectl -n argocd exec deploy/argocd-server -- argocd version --short

# Verify tracking method is annotation (default in 3.x)
kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.application\.resourceTrackingMethod}'
# Should return "annotation" or be empty (annotation is default)

# Verify reconciliation timeout is 30s for demo
kubectl -n argocd get configmap argocd-cmd-params-cm -o jsonpath='{.data.timeout\.reconciliation}'

# Verify self-heal is enabled on all apps
kubectl -n argocd get applications -o jsonpath='{range .items[*]}{.metadata.name}: selfHeal={.spec.syncPolicy.automated.selfHeal}{"\n"}{end}'

# Verify all applications are synced and healthy
kubectl -n argocd get applications
# Or use argocd CLI:
argocd app list

# Check sync status of a specific app
argocd app get root-app --refresh

# Verify sync waves are ordered correctly
kubectl -n argocd get applications -o jsonpath='{range .items[*]}{.metadata.annotations.argocd\.argoproj\.io/sync-wave} {.metadata.name}{"\n"}{end}' | sort -n

# Verify RBAC policy is loaded
kubectl -n argocd get configmap argocd-rbac-cm -o yaml

# Check for any degraded or out-of-sync applications
argocd app list --status Degraded
argocd app list --status OutOfSync

# Verify app-of-apps root is managing child apps
argocd app get root-app --show-resources

# Verify chart version deployed (should be 9.x for ArgoCD 3.3.x)
helm -n argocd list -o json | jq '.[].chart'

# Check ArgoCD server logs for errors
kubectl -n argocd logs deploy/argocd-server --tail=50

# Verify no label-based tracking annotations on resources
kubectl get all -A -o jsonpath='{range .items[*]}{.metadata.labels.argocd\.argoproj\.io/instance}{end}'
# Should be empty; annotation-based tracking uses annotations, not labels
```
