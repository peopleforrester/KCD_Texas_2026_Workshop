# Phase 2 — GitOps Bootstrap

**Skill:** `.claude/skills/argocd-patterns.md`
**Ground truth:** `gitops/bootstrap/app-of-apps.yaml`
**Test gate:** `tests/test_phase_02_gitops.py`

---

## Goal

Install ArgoCD on the cluster, then apply the app-of-apps Application that points at `gitops/apps/`. ArgoCD discovers **32 child Applications** and starts reconciling them in sync-wave order in parallel. By the end of Phase 2, the entire platform is *deploying*. Phases 3 → 7 are about waiting for each band of components to reach Healthy and scoring them.

This is the highest-leverage phase of the workshop. One paste, one `kubectl apply`, and ArgoCD is doing all the work for the rest of the 90 minutes.

## The prompt I paste to Claude

```
Read .claude/skills/argocd-patterns.md and spec/phases/phase-02-gitops.md.

Phase 2 is two steps:

Step A — Install ArgoCD via Helm:
  - Chart: argo/argo-cd from https://argoproj.github.io/argo-helm
  - Version: current stable GA (the 9.x line — chart 9.x is ArgoCD v3.4.x)
  - Namespace: argocd (pre-created)
  - Workshop tweaks: 30-second reconciliation timeout in configs.cm,
    server --insecure (no TLS termination for the workshop)
  - Give me the exact helm repo add / helm install commands.

Step B — Generate ~/my-app-of-apps.yaml:
  - Name: app-of-apps, namespace argocd
  - Source: https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git,
    branch main, path gitops/apps
  - Destination: in-cluster, argocd namespace
  - Automated sync with prune + selfHeal
  - Retry policy: 5 attempts, exponential backoff 5s → 3min cap
  - Finalizer: resources-finalizer.argocd.argoproj.io

After both files exist, diff my generated file against the pre-committed one:
  diff ~/my-app-of-apps.yaml gitops/bootstrap/app-of-apps.yaml

Walk me through every difference. Then I'll apply the pre-committed bootstrap
and we'll verify ArgoCD discovers all 32 children.

When the gate below passes, emit:
<promise>PHASE_2_DONE</promise>
```

## The test gate

```bash
# Gate 1: ArgoCD core pods Running
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller-0,
#           argocd-redis, argocd-dex-server, argocd-applicationset-controller,
#           argocd-notifications-controller — all Running

# Gate 2: Apply the bootstrap
kubectl apply -f gitops/bootstrap/app-of-apps.yaml

# Gate 3: app-of-apps + 32 child Applications discovered
kubectl get application -n argocd
# Expected within 30-60s: 33 Applications, app-of-apps + 32 children

# Gate 4: UI reachable (so we can show drift detection later)
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
# Browser: http://localhost:8080 — admin / <password above>
```

## Known failure modes

- **`configs.cm` vs `configs.params`** — `timeout.reconciliation` goes under `configs.cm`, not `configs.params`. Wrong path = silent no-op.
- **`application.resourceTrackingMethod: "label"`** — legacy 2.x. ArgoCD 3.x uses annotation-based tracking by default. Don't set the method explicitly.
- **`targetRevision: staging`** — pre-committed bootstrap targets `main`. ArgoCD must read canonical (main), not in-flight (staging).
- **Children all OutOfSync after sync** — Kyverno's admission webhook and the apiserver inject default fields not in git. Fixed by `ignoreDifferences` blocks on `gitops/apps/kyverno.yaml` and `gitops/apps/kyverno-policies.yaml`. Without those, Phase 2 gate's "all Synced" assertion fails.

## What students see on their cluster

Same paste, same `kubectl apply`. Their ArgoCD also discovers the same 32 child Applications because the bootstrap points at the *public canonical* `gitops/apps/` on `main` of this repo.

## Score on the live scorecard

**Components covered:** ArgoCD Install + Config, App-of-Apps Pattern, Sync Waves + Ordering (3 of 27)

- **Install** — Did ArgoCD come up Healthy on first chart install? Did the bootstrap discover the 32 children?
- **Integration** — Are the sync waves firing in order? Repo creds resolving? UI reachable?
- **Usability** — Can I log in? Can I see drift if I edit a Deployment? Are the Application states understandable?

Move to Phase 3 to score what the platform's security stack looks like as it reconciles in.
