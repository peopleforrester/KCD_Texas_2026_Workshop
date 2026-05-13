# Kyverno Policies Skill

Use this skill **before generating any Kyverno manifest.** The workshop uses Kyverno chart `3.8.0` (Kyverno `v1.18.0`) with three ClusterPolicies enforced on the `apps` namespace only.

## Critical version pins

| Thing | Workshop value |
|---|---|
| Helm chart | `kyverno/kyverno` |
| Chart version | `3.8.0` |
| Kyverno app version | `v1.18.0` |
| ClusterPolicy API | `kyverno.io/v1` |
| Mode | `validationFailureAction: Enforce` (capital E — case sensitive) |
| Background scan | `background: false` (workshop default — only validates new resources) |

## The workshop's architecture in one sentence

Two ArgoCD Applications: `kyverno` (sync wave -5, installs the chart) and `kyverno-policies` (sync wave -4, applies the three ClusterPolicy files from `gitops/manifests/kyverno-policies/`). System-namespace exclusion is handled **at the chart level** via the webhook `namespaceSelector`, not inside individual policies. This is cleaner than per-policy excludes.

## Pattern 1 — Kyverno install (Application with chart values)

Matches `gitops/apps/kyverno.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    chart: kyverno
    repoURL: https://kyverno.github.io/kyverno
    targetRevision: "3.8.0"
    helm:
      valuesObject:
        admissionController:
          replicas: 1                  # Workshop scale; production wants 3+
        config:
          webhooks:
            namespaceSelector:
              matchExpressions:
                - key: kubernetes.io/metadata.name
                  operator: NotIn
                  values:
                    - kube-system
                    - kube-public
                    - kube-node-lease
                    - argocd
                    - monitoring
                    - backstage
                    - kyverno
                    - sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: kyverno
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

**Why webhook namespaceSelector (vs per-policy excludes):**

- Single source of truth for exclusions — change one place, every policy respects it
- The webhook itself is bypassed for excluded namespaces, so policy evaluation never even runs there — faster, simpler, less risk of system-pod blocks
- Verified: `helm template kyverno/kyverno 3.8.0` with these values renders the webhook with the matchExpressions correctly applied

## Pattern 2 — kyverno-policies Application (directory source)

Matches `gitops/apps/kyverno-policies.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno-policies
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-4"     # After kyverno install (wave -5)
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git
    targetRevision: main
    path: gitops/manifests/kyverno-policies
    directory:
      recurse: false                       # Single dir, not subtrees
  destination:
    server: https://kubernetes.default.svc
    namespace: kyverno                     # Destination namespace; ClusterPolicies are cluster-scoped, namespace is just metadata
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

## Pattern 3 — ClusterPolicy: require-labels

Matches `gitops/manifests/kyverno-policies/require-labels.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
  annotations:
    policies.kyverno.io/title: Require app and team labels
    policies.kyverno.io/category: Workshop / Best Practices
    policies.kyverno.io/severity: medium
spec:
  validationFailureAction: Enforce
  background: false               # Don't background-scan; only validate new resources
  rules:
    - name: check-required-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - apps               # Only fire on Pods in the apps namespace
      validate:
        message: "Pods in 'apps' must have non-empty 'app' and 'team' labels."
        pattern:
          metadata:
            labels:
              app: "?*"              # `?*` means "any non-empty value"
              team: "?*"
```

## Pattern 4 — ClusterPolicy: require-resource-limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-resource-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - apps
      validate:
        message: "Pods in 'apps' must declare CPU and memory limits."
        pattern:
          spec:
            containers:                  # Applies the pattern to EACH container in the list
              - resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"
```

## Pattern 5 — ClusterPolicy: disallow-privileged (uses conditional anchors)

This is the policy that has the conditional anchor trick — `=(field)` means "if this field exists, it must match." Without conditional anchors the policy is too strict and rejects pods that simply don't set `securityContext`.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: deny-privileged
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - apps
      validate:
        message: "Privileged containers are not allowed in 'apps'."
        pattern:
          spec:
            =(initContainers):              # If initContainers exists,
              - =(securityContext):         # and if it has securityContext,
                  =(privileged): "false"    # then privileged must be false
            containers:                     # Always check regular containers (no anchor here)
              - =(securityContext):
                  =(privileged): "false"
```

## Common failure modes

| What you see | Cause | Fix |
|---|---|---|
| ArgoCD itself stops reconciling after policies install | Forgot `argocd` in the webhook namespaceSelector exclusion | Add `argocd` to the chart's `config.webhooks.namespaceSelector` exclusions |
| Policy installs but doesn't enforce | `validationFailureAction: enforce` (lowercase) | Change to `Enforce` (capital E) |
| `unrecognized field "kinds"` on apply | Used old `match.resources.kinds` (flat) form | Switch to `match.any[].resources.kinds` |
| Compliant pod gets rejected | `match.any[].resources.namespaces` includes more than `apps`, or anchor missing on optional field | Narrow match to `[apps]` only; add `=(field)` conditional anchor for optional fields |
| Background-scan noise on workshop install | `background: true` | Set `background: false` for workshop policies |

## Verify commands

```bash
# Controller pods
kubectl get pods -n kyverno
# Expected: kyverno-admission-controller, kyverno-background-controller,
#           kyverno-cleanup-controller, kyverno-reports-controller — all Running

# Policies loaded
kubectl get clusterpolicy
# Expected: require-labels, require-resource-limits, disallow-privileged
#           VALIDATE ACTION = Enforce, READY = true

# Block a non-compliant pod
kubectl run test-bad --image=nginx -n apps
# Expected: error from server — admission webhook denied

# Allow a compliant pod
kubectl apply -f - <<'EOF'
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
# Cleanup:
kubectl delete pod -n apps test-good --ignore-not-found

# System namespaces unaffected
kubectl get pods -n kube-system
# Expected: all Running
```

## What NOT to generate

- `kind: Policy` (namespaced) when you want cluster-wide — use `ClusterPolicy`
- `match.resources.kinds:` (flat) — use `match.any[].resources.kinds`
- `validationFailureAction: enforce` (lowercase) — must be `Enforce`
- Per-policy `exclude.any[].resources.namespaces` — the chart's webhook namespaceSelector handles this; per-policy excludes create two sources of truth
- `background: true` without a reason — workshop uses `false`
- ClusterPolicy targeting `kinds: ['*']` — overly broad; scope to `Pod` for these policies
