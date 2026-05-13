# Phase 2 — Kyverno + the `require-labels` policy

**Skill:** `.claude/skills/kyverno-policies.md`
**Ground truth:**
- `gitops/apps/kyverno.yaml` (admission controller chart)
- `gitops/manifests/kyverno-policies/require-labels.yaml` (the one policy we generate live)

The two other ClusterPolicies (`require-resource-limits`, `disallow-privileged`) are pre-committed and already deploying via ArgoCD from Phase 1. We don't regenerate them live — one is enough to demonstrate the pattern and there isn't time for three.

---

## Goal

Walk through the Kyverno chart Application that's *already deploying* via Phase 1's app-of-apps. Have Claude explain the architecture: separate Applications for install (wave -5) and policies (wave -4), webhook-level namespace exclusions via the chart's `config.webhooks.namespaceSelector` (not per-policy excludes). Then generate one ClusterPolicy live (`require-labels`), diff it against the pre-committed one, and prove enforcement with a non-compliant pod that gets rejected.

## What the audience sees

- Phase 1's pre-committed Kyverno is already coming up on the cluster (ArgoCD is reconciling from `gitops/apps/`)
- I have Claude generate one new policy live so they see the spec-driven authoring flow
- I demonstrate enforcement by deliberately creating a bad pod that admission rejects

## The prompt I paste to Claude

```
Read .claude/skills/kyverno-policies.md and spec/phases/phase-02-kyverno.md.

First, walk me through what's already deploying on the cluster from Phase 1's
app-of-apps. Specifically explain:
  1. Why is there a separate Application for the chart install (wave -5) AND
     a separate Application for the policies (wave -4)? What breaks if I
     combine them?
  2. The webhook namespaceSelector in gitops/apps/kyverno.yaml excludes
     kube-system, kube-public, kube-node-lease, argocd, monitoring, backstage,
     kyverno, sample-app. Why exclude 'argocd' specifically? What would happen
     during install if it weren't excluded?
  3. The policies use match.any[].resources.namespaces: [apps] to scope. Why
     do we need that AND the webhook namespaceSelector? Isn't it redundant?

Second, generate ONE ClusterPolicy live:
  - File: ~/my-require-labels.yaml
  - apiVersion: kyverno.io/v1, kind: ClusterPolicy
  - Name: require-labels
  - validationFailureAction: Enforce, background: false
  - match.any[].resources.kinds: [Pod], namespaces: [apps]
  - validate.pattern requires non-empty 'app' and 'team' labels on metadata.labels
  - No per-policy exclude block (the chart's webhook handles system exclusion)

Third, diff it against the pre-committed reference:
  diff ~/my-require-labels.yaml gitops/manifests/kyverno-policies/require-labels.yaml

Walk me through every difference. Flag anything that would actually change
admission behavior vs anything that's stylistic.

When the gate below passes, output:
<promise>PHASE_2_DONE</promise>
```

## The test gate

```bash
# Gate 1: Kyverno controllers Running
kubectl get pods -n kyverno
# Expected: kyverno-admission-controller, kyverno-background-controller,
#           kyverno-cleanup-controller, kyverno-reports-controller — all Running

# Gate 2: All three policies loaded (the pre-committed ones plus the one we just authored)
kubectl get clusterpolicy
# Expected: require-labels, require-resource-limits, disallow-privileged
#           VALIDATE ACTION = Enforce, READY = true

# Gate 3: A non-compliant pod is REJECTED
kubectl run test-bad --image=nginx -n apps
# Expected:
#   Error from server: admission webhook ... denied the request:
#   validation error: Pods in 'apps' must have non-empty 'app' and 'team' labels.

# Gate 4: A compliant pod is ACCEPTED
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

# Gate 5: Cleanup, confirm system pods unaffected
kubectl delete pod -n apps test-good --ignore-not-found
kubectl get pods -n kube-system | head -5
# Expected: all Running — webhook namespaceSelector excludes system namespaces
```

All five pass → score and move to Phase 3.

## Known failure modes (narrate if they happen on stage)

- **`validationFailureAction: enforce`** (lowercase). Kyverno is case-sensitive. Must be `Enforce`.
- **Per-policy `exclude.any` block.** Old-tutorial pattern. Workshop uses chart-level webhook namespaceSelector instead — single source of truth. If Claude adds per-policy excludes, point at the ground truth.
- **`match.resources.kinds`** (flat form). Current API is `match.any[].resources.kinds` (structured). Flat form fails validation on Kyverno 1.18+.
- **`background: true`.** Workshop policies use `background: false` to avoid background-scan noise during install. AI defaults can vary.

## What students see on their cluster

Their pre-committed Kyverno Application is already reconciling from Phase 1's bootstrap. Their three ClusterPolicies are already loaded. They run the same `kubectl run test-bad` command and watch admission reject the same way I do on stage. Their generated `~/my-require-labels.yaml` diffs cleanly against the pre-committed one (or doesn't, in which case they note the gap on their scorecard).

## Score on the live scorecard

**Two rows** because install and policy authoring are distinct AI failure surfaces.

**Row: Kyverno install** (the chart)
- Install — Did Claude's chart-install explanation align with the pre-committed Application?
- Integration — Webhook scoped right? Pods unaffected in system namespaces?
- Usability — Are the four controller pods understandable? Logs sensible?

**Row: Kyverno policies** (the live-authored one + the pre-committed ones)
- Install — Did Claude's generated policy syntactically match the reference? Did all three policies show up as Enforce / Ready?
- Integration — Did admission actually fire on the bad pod and allow the good one?
- Usability — Was the violation message clear enough that a developer could self-correct?

Move to Phase 3.
