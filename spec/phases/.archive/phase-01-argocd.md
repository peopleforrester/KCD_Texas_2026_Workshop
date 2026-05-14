# Phase 1 — ArgoCD + app-of-apps

**Skill:** `.claude/skills/argocd-patterns.md`
**Ground truth:** `gitops/bootstrap/app-of-apps.yaml`
**Test gate:** `tests/test_phase_01_argocd.py` (pytest — all must pass for promise)

---

## Goal (announced to the room before the prompt)

Bootstrap ArgoCD on the cluster, then generate the app-of-apps Application manifest that points ArgoCD at this repo's `gitops/apps/` directory. ArgoCD discovers four child Applications (Kyverno, kyverno-policies, kube-prometheus-stack, Backstage) and starts installing them in sync-wave order.

When the gate passes, ArgoCD UI shows five Applications and the room watches the rest of the platform start coming up behind the scenes while we move to Phase 2.

## What the audience sees

- My terminal on the projector left
- The live scorecard on the projector right, with the ArgoCD bootstrap row about to fill in
- Their own terminal mirroring my commands (Claude on their cluster, running roughly what mine runs)

## The prompt I paste to Claude

```
Read .claude/skills/argocd-patterns.md and spec/phases/phase-01-argocd.md.

Phase 1 is two steps:

Step A — Install ArgoCD via Helm:
  - Chart: argo/argo-cd from https://argoproj.github.io/argo-helm
  - Version: current stable GA (the 9.x line — chart 9.x is ArgoCD v3.x)
  - Namespace: argocd (already exists)
  - Workshop tweaks: 30-second reconciliation timeout in configs.cm,
    server --insecure (we're not terminating TLS for the workshop)
  - Give me the exact helm repo add / helm install commands.

Step B — Generate ~/my-app-of-apps.yaml:
  - Name: app-of-apps, namespace argocd
  - Source: this repo (https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git),
    branch main, path gitops/apps
  - Destination: in-cluster, argocd namespace
  - Automated sync with prune + selfHeal
  - Retry policy: 5 attempts, exponential backoff 5s → 3min cap
  - Finalizer: resources-finalizer.argocd.argoproj.io

After both files exist, diff my generated file against the pre-committed one:
  diff ~/my-app-of-apps.yaml gitops/bootstrap/app-of-apps.yaml

Walk me through every difference. Then I'll apply the pre-committed bootstrap
and we'll verify ArgoCD discovers the four children.

When the gate commands below all pass, output:
<promise>PHASE_1_DONE</promise>
```

## The test gate (presenter runs these out loud)

```bash
# Gate 1: ArgoCD core pods Running
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller-0,
#           argocd-redis — all Running

# Gate 2: Apply the bootstrap (idempotent)
kubectl apply -f gitops/bootstrap/app-of-apps.yaml

# Gate 3: Four children discovered, app-of-apps Synced
kubectl get application -n argocd
# Expected within ~30s:
#   app-of-apps             Synced  Healthy
#   kyverno                 Synced  Healthy / Progressing
#   kyverno-policies        Synced  Healthy / Progressing
#   kube-prometheus-stack   Synced  Healthy / Progressing
#   backstage               Synced  Healthy / Progressing

# Gate 4: Confirm the UI is reachable (so we can show drift detection later)
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
# Browser: https://localhost:8080 — admin / <password from above>
```

When all four pass, Claude outputs the promise. Score on the live scorecard.

## Known failure modes (for narrating live if the gate fails)

These are the patterns AI tends to fall into without the skill file. If the gate fails, name the pattern out loud — it's part of the talk.

- **`timeout.reconciliation` at the wrong path.** Goes under `configs.cm`, not `configs.params`. If Claude generated `configs.params."timeout.reconciliation"`, the override silently doesn't apply. Catch by checking the rendered `argocd-cm` ConfigMap.
- **`application.resourceTrackingMethod: "label"`.** That's legacy 2.x. ArgoCD 3.x uses annotation-based tracking by default. Don't set the method explicitly.
- **Wrong targetRevision.** Pre-committed bootstrap targets `main`. If Claude generates `targetRevision: staging`, ArgoCD reads from the working branch instead of canonical. Real bug.

## What students see on their cluster during this phase

Their own Claude is doing roughly the same thing — pulling the chart, generating the bootstrap. They `helm install` ArgoCD into their cluster and `kubectl apply` the bootstrap. Their ArgoCD instance also discovers the four children from this same repo, because the bootstrap points at the *public* canonical `gitops/apps/`.

By the end of Phase 1, every student's cluster has ArgoCD reconciling the same four pre-committed Applications. Their Phase 2 onward is about understanding what's actually deploying — not pushing different things to their fork.

## Score on the live scorecard

**Row: ArgoCD bootstrap + app-of-apps**

- **Install** — Did Claude generate a manifest that, after applying, brought ArgoCD up healthy? Did the bootstrap discover the children?
- **Integration** — Sync waves on the children working? Repo creds resolved? UI reachable?
- **Usability** — Can I log in? Can I see drift if I edit a Deployment? Are the Application states understandable?
- **Cycles** — count of follow-up prompts I had to send Claude
- **AI time** — wall clock paste-to-gate-passes

Students fill the same row on their card during the score moment.

Move to Phase 2.
