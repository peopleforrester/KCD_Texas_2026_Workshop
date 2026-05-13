# KCD Texas 2026 — Student Playbook

**Workshop:** "The 90-Minute IDP" • **Date:** May 15, 2026 • **Tool:** Claude Code

## Orientation (for readers reviewing this before the workshop)

This is the student-facing walkthrough for a 90-minute hands-on workshop at KCD Texas 2026. The audience is platform engineers, SREs, and Kubernetes practitioners who want a concrete look at what AI-assisted IDP work looks like in practice — not a slide deck about AI, but actual hands-on time using [Claude Code](https://docs.claude.com/en/docs/claude-code) against a real EKS cluster.

Each of the ~60 attendees gets a dedicated, pre-provisioned EKS cluster on AWS. ArgoCD and four IDP components (Kyverno, kube-prometheus-stack, Backstage) are pre-staged in this repository's `gitops/` directory. Students bootstrap ArgoCD on their cluster, point it at this repo, and ArgoCD installs the four components. The workshop's pedagogical model is a **guided tour**: Claude Code walks each student through the pre-committed manifests in `gitops/apps/`, explains why they're structured that way, and helps them verify each component installed correctly. By the end, every student has a working IDP they can poke at.

The point isn't to demonstrate that AI can write Helm values. The point is to ask, honestly, **whether AI shifted the toil or actually shrunk it** — which is why the per-phase scorecard at [`scorecard/SCORECARD-TEMPLATE.md`](scorecard/SCORECARD-TEMPLATE.md) captures correction cycles, AI time, and a wrap-up reflection on toil-shifting. Aggregated results (opt-in submission) inform a follow-on talk.

**About the framework.** The Kyverno policies and admission controls you'll see today are server-side enforcement controls in the **Agentic Covenants** framework — a prevention-first matrix for autonomous-agent governance. Today's workshop is a 90-minute worked example of one column of that matrix: the Authorization and Blast-radius rows, server-side. The full framework — five concerns × three layers × fifteen cells, with citations to NIST CSF 2.0, NIST AI RMF, OWASP LLM Top 10, and OWASP Agentic Top 10 — lives at [github.com/peopleforrester/agentic-covenants](https://github.com/peopleforrester/agentic-covenants).

---

You walk in, your EKS cluster is already running, and in 90 minutes you'll see and understand a working Internal Developer Platform on top of it: GitOps with ArgoCD, policy enforcement with Kyverno, observability with Prometheus + Grafana, and a developer portal with Backstage.

You don't type Kubernetes YAML from scratch. You **describe what you want to Claude Code**, paste the prompts below, run the verification command, and move on.

> **About versions.** The prompts say "current stable GA chart" instead of pinned chart numbers. The Application manifests in `gitops/apps/` are pinned (workshop maintainers update them before each event), but you don't need to memorize those numbers — Claude can read the file when you ask.

> **How you'll build.** The workshop uses a **spec-driven build** modeled on the
> kubeauto reference build (`github.com/peopleforrester/kubeauto-ai-day`).
> Claude Code reads:
> - `spec/WORKSHOP-BUILD-SPEC.md` — the 4-phase condensed spec
> - `.claude/skills/{argocd-patterns,kyverno-policies,backstage-templates}.md` — encoded patterns, version pins, and known correction cycles
> - `.claude/commands/workshop-phase.md` — defines the `/workshop-phase` slash command
> - The reference manifests in `gitops/apps/` — what the end state should look like
>
> You invoke `/workshop-phase 1`, Claude Code reads everything above, builds the
> component, verifies with `kubectl`, prompts you to score, and emits a phase
> completion promise. The stop hook at `.claude/hooks/cc-stop-deterministic.sh`
> keeps Claude on-task until each phase actually verifies.
>
> If you fall behind, every phase has a **Tour fallback**: open the pre-committed
> manifest in `gitops/apps/` and have Claude walk you through it. Same end state,
> less explanation of how you got there. Switching modes mid-phase is fine.

---

## Prerequisites

You should arrive with:

- A laptop with terminal access, **kubectl**, the **AWS CLI**, and **git** installed
- **Claude Code** installed and authenticated on the laptop (every attendee runs Claude Code against their own cluster — this is hands-on, not observe-the-presenter)
- Comfortable with kubectl basics (pods, deployments, services, namespaces) and a CLI
- Helm and ArgoCD experience helpful but not required — you'll see both in action

If Claude Code isn't installed before you walk in, you'll lose 10 minutes to install + auth and the workshop will already be in Phase 1. Install ahead of time.

## Before You Start (5 min)

**Your connection card** is a small handout you'll receive at registration. It looks like this:

```
================================================================
KCD Texas 2026 — "The 90-Minute IDP" — Connection Card

Cluster:        kcd-texas-student-23
Region:         us-east-2

AWS Access Key: AKIAxxxxxxxxxxxxxxxx
AWS Secret Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Workshop repo:  https://github.com/peopleforrester/KCD_Texas_2026_Workshop

If you get stuck, raise your hand.  TAs are circulating.
================================================================
```

The workshop repo is the same repository you're reading this playbook from. ArgoCD will pull from it; you'll clone it locally so Claude Code can show you what's inside.

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

# 5. Clone the workshop repo locally
git clone https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git ~/kcd-texas-workshop
cd ~/kcd-texas-workshop

# 6. Start Claude Code in that directory
claude
```

If `kubectl get nodes` fails or shows fewer than 3 nodes, **raise your hand**. We have spare clusters.

### Bring your own cluster (BYOC)

If you're using your own cluster instead of the workshop EKS one (per the abstract: *"Got your own cluster? Bring that too"*), skip the `aws configure` / `aws eks update-kubeconfig` steps. Your cluster needs to meet three conditions:

- `kubectl get nodes` returns **at least 3 Ready nodes** with roughly **16 GB total spare RAM** (Prometheus + Grafana + Backstage + ArgoCD adds up; see `lab-requirements-may-2026-events.md` for the per-component footprint)
- You have **`cluster-admin`** — installing CRDs and admission webhooks needs it
- The six workshop namespaces exist; if not, create them: `kubectl create ns argocd kyverno monitoring backstage apps sample-app`

Then jump to step 5 of the preflight (clone the workshop repo) and continue normally. Phase 1's ArgoCD install picks up whatever kubeconfig is active — no AWS-specific assumptions in the GitOps source.

### Preflight troubleshooting (before you call a TA over)

| Symptom | First-pass fix |
|---|---|
| `aws configure` rejects the keys | Re-enter carefully — Secret Keys often get pasted with leading/trailing whitespace. Confirm region is `us-east-2`, format `json`. |
| `aws sts get-caller-identity` fails | Your keys aren't reaching AWS. Check `~/.aws/credentials` actually got written. |
| `aws eks update-kubeconfig` returns "AccessDenied" | Your IAM user may not have access to the cluster yet — raise your hand. |
| `kubectl get nodes` returns "Unauthorized" | The cluster's `aws-auth` ConfigMap doesn't have your user mapped — raise your hand; a TA can patch it in 30 seconds. |
| `kubectl get nodes` shows fewer than 3 nodes | Node still scheduling — wait 30 seconds. If still short, raise your hand for a spare. |

**How this playbook works.** Each of the four phases gives you:

1. **Goal** — what you'll see by the end of the phase
2. **Prompt** — copy-paste into Claude Code
3. **Verify** — one or two commands that prove it worked
4. **If broken** — the most common failure and the fix
5. **Scorecard** — record your numbers (you'll fill in the full scorecard at the end)

The prompts assume Claude Code can read this repo. Anything Claude needs to know about Helm chart values, sync waves, or Backstage's backend system is either in the manifest files under `gitops/` or in this playbook.

---

## Phase 1 — Bootstrap ArgoCD and the IDP (~20 min)

### Goal

Install ArgoCD via Helm. Apply the **app-of-apps** root Application. Watch ArgoCD discover the five IDP components in `gitops/apps/` and start installing them. By the end of this phase, you'll have ArgoCD running, five child Applications visible in `argocd app list`, and components reaching `Synced` / `Healthy` state over the next few minutes.

### Prompt

In Claude Code, type:

```
/workshop-phase 1
```

Claude reads `spec/WORKSHOP-BUILD-SPEC.md`, the `argocd-patterns` skill file, and
`gitops/bootstrap/app-of-apps.yaml`, then bootstraps ArgoCD via Helm with the
correct version pins and values paths (the skill file encodes the chart 9.x ↔
ArgoCD 3.3.x mapping and the `configs.cm` vs `configs.params` correction), then
applies the app-of-apps. The stop hook holds Claude on the phase until you see
five child Applications progressing and Claude emits
`<promise>WORKSHOP_PHASE_1_DONE</promise>`.

**Tour fallback:** if `/workshop-phase 1` runs long or you want to skip ahead,
say: *"Switch to Tour mode. Open `gitops/bootstrap/app-of-apps.yaml`, explain
what it does, then I'll `kubectl apply` it manually."*

### Verify

```bash
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller,
# argocd-redis -- all Running.

kubectl get application -n argocd
# Expected (after a couple minutes):
#   NAME                     SYNC STATUS   HEALTH STATUS
#   app-of-apps              Synced        Healthy
#   kyverno                  Synced        Healthy        (or Progressing)
#   kyverno-policies         Synced        Healthy
#   kube-prometheus-stack    Synced        Healthy        (or Progressing)
#   argocd-servicemonitors   Synced        Healthy        (waits for kube-prom-stack CRDs)
#   backstage                Synced        Healthy        (or Progressing)
```

### If Broken

| Symptom | Fix |
|---|---|
| `argocd-server` pod stuck `Pending` | Run `kubectl describe pod -n argocd <pod>` — usually image pull or scheduling. Tell Claude: "the pod is Pending because <reason>, fix it." |
| `app-of-apps` Application stuck `Progressing`, `repo not accessible` | The repo is reachable but ArgoCD's repo-server may need DNS or a fresh fetch. Tell Claude: "the repo-server can't reach github.com — check DNS in the pod and force an ArgoCD repo refresh." |
| Helm install fails with "chart not found" | Helm repo isn't refreshed. Tell Claude: "run `helm repo update` first, then retry the install." |
| Children Applications show `OutOfSync` after a few minutes | Likely benign during initial install (CRDs racing pods). Watch for 2–3 minutes; if still `OutOfSync`, hard-refresh that Application in the ArgoCD UI. |

### Scorecard for Phase 1

- AI time (wall clock): __ min
- Correction cycles: __
- Toil reduced (1–10): __
- Integration (1–10) — did the five child Applications auto-discover and start installing cleanly?: __
- Tour or DIY: __ (circle one)
- Notes: __

---

## Phase 2 — Understand and Test Kyverno (~20 min)

### Goal

Understand what `gitops/apps/kyverno.yaml` and `gitops/apps/kyverno-policies.yaml` actually deploy: a Kyverno admission controller plus three ClusterPolicies (`require-labels`, `require-resource-limits`, `disallow-privileged`) enforced only on the `apps` namespace. Then watch those policies block a non-compliant pod and let a compliant one through.

### Prompt

```
/workshop-phase 2
```

Claude reads the `kyverno-policies` skill file (which encodes the webhook
`namespaceSelector` map-vs-list correction and the `ServerSideApply=true`
requirement for the policy CRDs), reviews `gitops/apps/kyverno.yaml`,
`gitops/apps/kyverno-policies.yaml`, and the three ClusterPolicy files under
`gitops/manifests/kyverno-policies/`, and verifies Kyverno admission is firing
on real pods (a non-compliant pod gets rejected; a compliant one passes).

**Tour fallback:** *"Switch to Tour mode. Walk me through `gitops/apps/kyverno.yaml`
+ the policies, explain sync wave -5 vs -4, and verify with `kubectl get
clusterpolicy`."*

### Verify

```bash
kubectl get pods -n kyverno
# Expected: kyverno-admission-controller, kyverno-background-controller,
# kyverno-cleanup-controller, kyverno-reports-controller -- all Running.

kubectl get clusterpolicy
# Expected: 3 policies -- require-labels, require-resource-limits, disallow-privileged
# All with VALIDATE ACTION = Enforce, READY = true.

# Try a non-compliant pod in apps -- admission should reject:
kubectl run test-bad --image=nginx -n apps
# Expected: error from server: admission webhook ... denied the request: ...
# (will cite require-labels and require-resource-limits)

# A compliant pod -- should succeed:
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

> **Heads-up:** Current Kyverno releases auto-generate Kubernetes-native `ValidatingAdmissionPolicy` resources alongside your `ClusterPolicy` objects on EKS 1.30+. You'll see them in `kubectl get validatingadmissionpolicy` — that's expected, not a bug.

### If Broken

| Symptom | Fix |
|---|---|
| Kyverno pods crash-looping | Check `kubectl describe pod -n kyverno <pod>` for image pull or webhook config errors. Tell Claude what you see. |
| `kubectl get clusterpolicy` returns nothing | The `kyverno-policies` Application hasn't synced yet, or the path is wrong. Check ArgoCD UI for the Application's status. |
| Compliant pod also gets rejected | Check the policy's `match` block — `apps` should be the only listed namespace. If something else is matching unexpectedly, ask Claude to explain which rule fired. |
| `test-bad` pod is *accepted* | Kyverno admission controller isn't actually enforcing yet (still warming up). Wait 30 seconds; if still accepted, check that the `validationFailureAction` is `Enforce` (not `Audit`). |

### Scorecard for Phase 2

- AI time: __ min  •  Corrections: __  •  Toil reduced: __ /10  •  Integration (1–10, did Kyverno actually block bad pods + allow good?): __  •  Tour or DIY: __  •  Notes: __

---

## Phase 3 — Understand and Open Prometheus + Grafana (~20 min)

### Goal

Understand `gitops/apps/kube-prometheus-stack.yaml` — what `kube-prometheus-stack` actually bundles (Prometheus, Grafana, node-exporter, kube-state-metrics; alertmanager is disabled for the workshop). Then open Grafana in your browser and confirm cluster metrics are flowing.

### Prompt

```
/workshop-phase 3
```

Claude reviews `gitops/apps/kube-prometheus-stack.yaml` and
`gitops/apps/argocd-servicemonitors.yaml`, opens Grafana via `kubectl
port-forward`, and verifies Prometheus is scraping ArgoCD's metrics endpoints
(the Phase 3 Integration question on the scorecard).

**Tour fallback:** *"Switch to Tour mode. Walk me through
`gitops/apps/kube-prometheus-stack.yaml`, explain the
`serviceMonitorSelectorNilUsesHelmValues: false` override, and tell me the
port-forward command for Grafana."*

### Verify

```bash
kubectl get pods -n monitoring
# Expected: prometheus-kube-prometheus-stack-prometheus-0,
# kube-prometheus-stack-grafana-*, kube-prometheus-stack-operator-*,
# kube-prometheus-stack-kube-state-metrics-*, prometheus-node-exporter-* (one per node).
# All Running.

kubectl get servicemonitor -n monitoring
# Expected: ~10+ ServiceMonitors created by the chart.

# Open Grafana:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# In your browser: http://localhost:3000
# User: admin  •  Password: kcd-texas
# Click Dashboards -> Browse -> "Kubernetes / Compute Resources / Cluster"
# -> graphs should be populated.
```

### If Broken

| Symptom | Fix |
|---|---|
| `prometheus-*-0` stuck `Pending` | Storage class issue. Tell Claude: "the Prometheus StatefulSet is Pending because of a PVC; check `kubectl describe statefulset` and propose a values change." |
| Grafana shows "no data" on every panel | Prometheus isn't scraping yet — wait 60s. If still empty, check that targets exist via the Prometheus UI: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`, then visit Status → Targets. |
| Helm install hangs > 3 min | Some sub-images may not be pre-pulled. Watch `kubectl get pods -n monitoring -w` for image-pull events. |

### Scorecard for Phase 3

- AI time: __ min  •  Corrections: __  •  Toil reduced: __ /10  •  Integration (1–10, is Grafana actually showing populated dashboards?): __  •  Tour or DIY: __  •  Notes: __

---

## Phase 4 — Understand and Open Backstage (~20 min)

### Goal

Understand `gitops/apps/backstage.yaml` — how the Backstage Helm chart deploys, what image it runs, and why the Backstage chart is unusual in not having a default image. Then open the Backstage portal in your browser and look at the catalog.

> The Application uses a community-built Backstage image (`roadiehq/community-backstage-image:1.50.4`). For a real workshop deliverable with software templates, the workshop maintainer would replace this with a workshop-specific image that bakes in the scaffolder plugin and a static catalog at `/app/catalog`. With the community image, you'll see a working Backstage with its default catalog — enough to demonstrate what a developer portal *is*, even if you can't run a custom template here.

### Prompt

```
/workshop-phase 4
```

Claude reads the `backstage-templates` skill file (which encodes the
legacy-backend-system correction — `createServiceBuilder()` and
`@backstage/backend-common` are removed), reviews `gitops/apps/backstage.yaml`,
and opens the portal via `kubectl port-forward`. Emits both
`<promise>WORKSHOP_PHASE_4_DONE</promise>` and `<promise>WORKSHOP_COMPLETE</promise>`
when verified.

**Tour fallback:** *"Switch to Tour mode. Walk me through `gitops/apps/backstage.yaml`,
explain why the chart has no default image, and tell me the port-forward command
for the portal."*

### Verify

```bash
kubectl get pods -n backstage
# Expected: backstage-* pod -- Running.

kubectl port-forward -n backstage svc/backstage 7007:7007
# In your browser: http://localhost:7007
# Click Catalog -> you should see a few demo entries from the community image's
# default catalog. (A workshop-specific image would replace these with our own.)
```

### If Broken

| Symptom | Fix |
|---|---|
| Backstage pod fails to start with `createServiceBuilder is not a function` or similar | The image was built against the legacy backend. The current chart will not run it. Tell a TA — this is a workshop maintainer issue, not something to fix in 20 minutes. |
| Backstage pod stuck `CrashLoopBackOff` with database errors | The chart's default in-cluster Postgres may have raced startup. Tell Claude: "Backstage is crashing on database connection; check that the `backstage-postgresql` pod is Running and that Backstage's `app-config` is pointing at it correctly." |
| Catalog page is empty | The community image has a small default catalog. If completely empty, the static-catalog ConfigMap mount may be missing — check `kubectl describe pod -n backstage <pod>` volume mounts. |

### Scorecard for Phase 4

- AI time: __ min  •  Corrections: __  •  Toil reduced: __ /10  •  Integration (1–10, did Backstage start cleanly + show a populated catalog?): __  •  Tour or DIY: __  •  Notes: __

---

## Wrap-Up (5 min)

Total your scorecard:

| Phase | AI time | Corrections | Toil reduced (1–10) | Integration (1–10) | Tour / DIY |
|---|---:|---:|---:|---:|:---:|
| 1 — ArgoCD bootstrap | __ | __ | __ | __ | __ |
| 2 — Kyverno | __ | __ | __ | __ | __ |
| 3 — Prometheus + Grafana | __ | __ | __ | __ | __ |
| 4 — Backstage | __ | __ | __ | __ | __ |
| **Total / Average** | __ | __ | __ | __ | — |

**Integration vs. installation:** "Toil reduced" measures how much manual install work AI eliminated. "Integration" is a separate question — *did it actually work end-to-end?* AI can install Kyverno cleanly and still produce policies that don't fire correctly. Score them independently.

For comparison, the reference build (a single experienced engineer running this same stack end-to-end without time pressure, and writing every manifest from scratch instead of touring pre-committed ones) took **31 minutes of pure AI time** across these four components and saw a **73.8% net toil reduction** vs. doing it by hand. Your numbers will be different — you're touring an IDP with a guide, not building one from scratch.

### What You Have Now

- An EKS cluster running an Internal Developer Platform that mirrors what most platform teams spend weeks setting up
- A real GitOps loop: ArgoCD watching this workshop repo and reconciling four Applications into your cluster
- Admission-time policy: bad pods are rejected before they ever run
- Cluster observability: Prometheus is scraping, Grafana is graphing
- A developer portal you can open and click through

### Where to Take It Next

Outside this room, on your own time, you can extend the same pattern to:

- Fork this repo and add a fifth Application. Examples: **Falco + Falco Talon** (Falco detects at the syscall layer; Talon adds response that acts fast enough to approximate prevention — the pair spans Detect and Respond in [Agentic Covenants](https://github.com/peopleforrester/agentic-covenants) terms), cert-manager for TLS, or ExternalSecrets pulling from AWS Secrets Manager.
- Build your own Backstage image with the scaffolder plugin and add a software template that creates a Kyverno-compliant Deployment
- Wire OpenTelemetry traces through an OTel Collector

The reference build at [github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day) shows the full 7-phase version of what you toured today — ~10 hours of build with all 27 components and the full scorecard.

### After the Workshop

**Your cluster is destroyed shortly after the session ends.** Up to 15 attendees can keep theirs for ~1 additional hour if you want to keep exploring; ask a TA at the end. Save anything you want to keep (Grafana screenshots, any manifests you generated in Claude Code) before you walk out.

**This repository stays public and bookmarkable.** Everything you saw today — the playbook, the GitOps source, the diagrams, the scorecard template — lives at [github.com/peopleforrester/KCD_Texas_2026_Workshop](https://github.com/peopleforrester/KCD_Texas_2026_Workshop) and isn't going anywhere. Fork it if you want to extend it; reference it freely.

**Your scorecard is yours.** If you're willing to share it (anonymized aggregation only — no names, no cluster IDs in the published version), drop the filled file at `scorecard.md` in your local clone before you leave the venue and a TA will collect it. Or keep it private; the personal-reflection value is the main point either way.

**Where to ask follow-on questions:** open an Issue on this repository. For deeper technical reference, the full 7-phase production version of what you toured today is at [github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day) — ~10 hours of build with all 27 components and the full scorecard data.

---

## If Something Is Really Stuck

If you've burned more than 5 minutes on a single failure and the "If broken" hints didn't help:

1. Raise your hand — a TA will come over.
2. If your cluster is genuinely broken, we have **spare clusters**. Your TA can move you to one and you can pick up from where the rest of the room is.
3. Don't try to fix infrastructure from scratch. The point of the workshop is to use Claude Code on a working substrate; lost time on the substrate is wasted time.
