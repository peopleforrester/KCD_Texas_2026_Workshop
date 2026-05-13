# KCD Texas 2026 — Student Playbook

**Workshop:** "The 90-Minute IDP" • **Date:** May 15, 2026 • **Tool:** Claude Code

## Orientation (for readers reviewing this before the workshop)

This is the attendee-facing companion to a **presenter-led, audience follow-along** workshop at KCD Texas 2026. Michael drives Claude Code live on stage with a build spec; ~60 attendees mirror the same prompts against their own pre-provisioned EKS clusters using Claude Code on their laptops. Real CNCF projects (ArgoCD, Kyverno, Prometheus + Grafana, Backstage), real `kubectl` test gates, real scorecard scored on three dimensions (Install / Integration / Usability) in real time on the projector.

The point is **not** to finish the IDP in 90 minutes. The point is to demonstrate spec-driven development with Claude Code on a real platform-engineering build, score what AI does honestly across three dimensions, and walk out with a methodology you can apply Monday morning.

**How far we get is how far we get.** Phase 4 might faceplant on stage — that's the talk title. If it does, Michael switches to a pre-recorded run for the closing 5 minutes; either way the scorecard fills in.

The full spec Michael hands Claude is at [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md) (~90 lines). The on-stage sequence is at [`spec/PRESENTER-RUNBOOK.md`](spec/PRESENTER-RUNBOOK.md). Per-phase prompts and gates are under [`spec/phases/`](spec/phases/). This playbook is what *you* the attendee do.

---

## Prerequisites

You should arrive with:

- A laptop with terminal access, **kubectl**, the **AWS CLI**, and **git** installed
- **Claude Code** installed and authenticated on the laptop (every attendee runs Claude Code against their own cluster — this is hands-on, not observe-the-presenter)
- Comfortable with kubectl basics (pods, deployments, services, namespaces) and a CLI
- Helm and ArgoCD experience helpful but not required — you'll see both in action

If Claude Code isn't installed before you walk in, you'll lose 10 minutes to install + auth and the workshop will already be in Phase 1. Install ahead of time.

---

## Before You Start (5 min)

**You claim your cluster credentials at the door.** A QR code on the projector (or by the door) points at a self-service landing page that hands you a unique pre-provisioned cluster. If the landing page is offline, fall back to the numbered cards in a stack at the door. Same content either way — it looks like this:

```
================================================================
KCD Texas 2026 — "The 90-Minute IDP"

Cluster:        kcd-texas-student-23
Region:         us-east-2

AWS Access Key: AKIAxxxxxxxxxxxxxxxx
AWS Secret Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Workshop repo:  https://github.com/peopleforrester/KCD_Texas_2026_Workshop

Michael is solo today — no TAs.  Use the setup window before T+0
to flag any problems.  After the build starts he's driving the
projector and can't help individuals.
================================================================
```

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
# Expected: 3 nodes, all Ready

# 4. Verify the workshop namespaces are pre-created
kubectl get ns argocd kyverno monitoring backstage apps sample-app
# Expected: all 6 namespaces, status Active

# 5. Clone the workshop repo locally
git clone https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git ~/kcd-texas-workshop
cd ~/kcd-texas-workshop

# 6. Start Claude Code in that directory
claude
```

If `kubectl get nodes` fails or shows fewer than 3 nodes, **raise your hand during the setup window** — Michael has spare cluster credentials in his pocket and will swap you in 30 seconds. Once Phase 1 starts he can't break away to help individuals.

### Bring your own cluster (BYOC)

If you brought your own cluster, skip the AWS configure + kubeconfig steps. Three preconditions to meet:

- `kubectl get nodes` returns at least **3 Ready nodes** with roughly **16 GB total spare RAM**
- You have **`cluster-admin`** (installing CRDs and admission webhooks needs it)
- The six workshop namespaces exist: `kubectl create ns argocd kyverno monitoring backstage apps sample-app`

Then jump to step 5 (clone the workshop repo) and continue normally.

### Preflight troubleshooting (during the setup window before T+0)

Fix yourself first; flag Michael only if it's not a 30-second fix.

| Symptom | First-pass fix |
|---|---|
| `aws configure` rejects the keys | Re-enter carefully — secrets often paste with leading/trailing whitespace. Confirm region is `us-east-2`, format `json`. |
| `aws sts get-caller-identity` fails | Your keys aren't reaching AWS. Check `~/.aws/credentials` actually got written. |
| `aws eks update-kubeconfig` returns "AccessDenied" | Your IAM user may not have access to the cluster yet — flag Michael, ask for a spare. |
| `kubectl get nodes` returns "Unauthorized" | The cluster's Access Entries don't have your user mapped — flag Michael, ask for a spare. |
| `kubectl get nodes` shows fewer than 3 nodes | Node still scheduling — wait 30 seconds. If still short, ask for a spare. |

---

## How this works (the follow-along model)

Michael drives Claude on stage. **You drive your own Claude on your own cluster.** The same prompts go in, the same `kubectl` commands come out the other side. The scorecard fills in on the projector and on your card simultaneously.

You have three options for participation:

1. **Mirror exactly.** Watch what Michael pastes, paste the same thing into your Claude. Run the same `kubectl` gate commands he runs. Score the same row he scores.
2. **Run the slash command directly.** Type `/build-phase N` in your Claude. Claude reads the same spec + skill files Michael's Claude is reading. You get to the same end state on a slightly different pace. Useful if you fall behind during a phase.
3. **Hybrid.** Watch Michael for the explanation, then run `/build-phase N` yourself for the build. Most people end up here.

You do **not** push to git. The repo is the canonical ground truth on `main`. Your cluster's ArgoCD reconciles from it directly. Manifests Claude generates for you live in `~/my-<component>.yaml` on your laptop — they're for understanding, not for deploying.

**About versions.** The skill files in [`.claude/skills/`](.claude/skills/) pin current chart and image versions. They're verified-working against real clusters as of May 13, 2026. If something in the chart upstream has moved between then and workshop day, the skill files will tell Claude what to do; your job is just to mirror and verify.

---

## Phase 1 — Bootstrap ArgoCD + app-of-apps (~20 min)

### What Michael will do on stage

Show `spec/BUILD-SPEC.md` briefly on the projector, then start `claude`, then paste a prompt that tells Claude to read the spec and run `/build-phase 1`. Claude:

1. Reads `.claude/skills/argocd-patterns.md`, `spec/phases/phase-01-argocd.md`, and `gitops/bootstrap/app-of-apps.yaml`
2. Walks through the architecture out loud
3. Generates `~/my-app-of-apps.yaml`
4. Diffs that against the pre-committed ground truth
5. Has Michael `helm install` ArgoCD and `kubectl apply` the bootstrap
6. Runs the gate commands; scores Install / Integration / Usability when they pass
7. Emits `<promise>PHASE_1_DONE</promise>`

### What you do

In your `claude` (already running from `~/kcd-texas-workshop`):

```
/build-phase 1
```

Claude reads the same files, generates `~/my-app-of-apps.yaml` on your laptop, and walks you through the same diff. The gate commands you run yourself:

```bash
# Gate 1: ArgoCD core pods are Running
kubectl get pods -n argocd

# Gate 2: Apply the bootstrap
kubectl apply -f gitops/bootstrap/app-of-apps.yaml

# Gate 3: Five child Applications discovered (~30s)
kubectl get application -n argocd
# Expected:
#   app-of-apps             Synced  Healthy
#   kyverno                 Synced  Healthy / Progressing
#   kyverno-policies        Synced  Healthy / Progressing
#   kube-prometheus-stack   Synced  Healthy / Progressing
#   argocd-servicemonitors  Synced  Healthy / Progressing
#   backstage               Synced  Healthy / Progressing
```

### Score Phase 1 on your scorecard

Row: **ArgoCD bootstrap + app-of-apps**
- **Install** (1–10): did Claude's generated manifest, after the apply, bring ArgoCD up healthy?
- **Integration** (1–10): did the bootstrap discover the five child Applications cleanly?
- **Usability** (1–10): can you reach the ArgoCD UI, log in, see drift if you edit something?
- Cycles (count of corrective prompts you sent Claude)
- AI time (wall clock from paste to gate-passing)

If any gate fails: the playbook's per-phase Known Failure Modes are in [`spec/phases/phase-01-argocd.md`](spec/phases/phase-01-argocd.md) — Claude reads them too. Most likely cause is `configs.params.timeout.reconciliation` at the wrong path (should be `configs.cm`).

---

## Phase 2 — Kyverno + a policy (~20 min)

### What Michael will do on stage

`/build-phase 2`. Claude reads `.claude/skills/kyverno-policies.md`, the phase file, and the ground-truth manifests. Generates `~/my-kyverno.yaml` (the install) and `~/my-require-labels.yaml` (one of three policies), diffs both, has Michael verify Kyverno is admission-firing on real pods.

### What you do

```
/build-phase 2
```

Gate commands:

```bash
# Gate 1: Kyverno controllers Running
kubectl get pods -n kyverno

# Gate 2: Three ClusterPolicies READY
kubectl get clusterpolicy
# Expected: 3 policies, all VALIDATE ACTION=Enforce, READY=true

# Gate 3: A non-compliant pod in apps is REJECTED
kubectl run test-bad --image=nginx -n apps
# Expected: admission webhook denied the request: require-labels, require-resource-limits

# Gate 4: A compliant pod is ACCEPTED
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: { name: test-good, namespace: apps, labels: { app: demo, team: workshop } }
spec:
  containers: [ { name: app, image: nginx, resources: { limits: { cpu: 100m, memory: 128Mi } } } ]
EOF

# Gate 5: A pod in kube-system (excluded namespace) is ACCEPTED
kubectl run test-system --image=nginx -n kube-system

# Cleanup
kubectl delete pod test-good -n apps
kubectl delete pod test-system -n kube-system
```

### Score Phase 2

Two rows in this phase: **Kyverno install** and **Kyverno policies**. Integration is the interesting score — did the policies *actually fire correctly*? Bad rejected, good accepted, system allowed. All three must hold.

Known traps Claude tends to fall into (from the skill file): webhook `namespaceSelector` as a YAML list instead of a map; Kyverno policies Application without `ServerSideApply=true`. If a gate fails, name the trap.

---

## Phase 3 — kube-prometheus-stack + ArgoCD ServiceMonitors (~20 min)

### What Michael will do on stage

`/build-phase 3`. Claude reads `.claude/skills/kube-prometheus-stack.md`. Generates `~/my-kube-prometheus-stack.yaml`, diffs against ground truth, has Michael port-forward Grafana on the projector — the *"does the dashboard have real data?"* moment is the talk's payoff for this phase.

### What you do

```
/build-phase 3
```

Gate commands:

```bash
# Gate 1: Prometheus + Grafana + node-exporter + kube-state-metrics + operator all Running
kubectl get pods -n monitoring

# Gate 2: ArgoCD ServiceMonitors exist
kubectl get servicemonitor -n argocd
# Expected: argocd-application-controller, argocd-repo-server, argocd-server

# Gate 3: Prometheus is actually scraping ArgoCD
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
sleep 3
curl -s 'http://localhost:9090/api/v1/targets' | \
  jq -r '.data.activeTargets[] | select(.scrapePool | contains("argocd")) | "\(.scrapePool) \(.health)"'
# Expected: 3 lines, all "up"
kill %1

# Gate 4: Grafana UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Browser: http://localhost:3000   (admin / kcd-texas)
# Dashboards → Browse → "Kubernetes / Compute Resources / Cluster" — should be populated
```

### Score Phase 3

Integration is the interesting score: is Prometheus *actually scraping* ArgoCD's metrics endpoints, AND is Grafana showing real cluster data? Both must hold.

Known trap (from the skill file): `ServerSideApply=true` is mandatory because the chart's CRDs exceed the 256KB annotation size limit. Without it, the sync fails.

---

## Phase 4 — Backstage (~20 min, or pre-recorded if time is tight)

### What Michael will do on stage

Two paths into Phase 4:

- **Path A (>20 min left, Phase 3 landed clean):** drive Phase 4 live. `/build-phase 4`. Watch the image config block in the diff — that's THE trap.
- **Path B (<10 min left, Phase 3 was rough):** play the pre-recorded Phase 4 video during the closing 5 minutes. Score it on the live scorecard from the recording.

Either path produces honest scorecard data. The trap that defines Phase 4: the Backstage chart has no default image. If Claude omits the image config, the Pod CrashLoopBackOffs. Plus the upstream image's baked-in app-config crashes the Kubernetes plugin without a cluster locator override — so `backstage.appConfig` with `kubernetes.clusterLocatorMethods: []` is required.

### What you do

If Path A:

```
/build-phase 4
```

Gate commands:

```bash
# Gate 1: Backstage Pod Running (the failure-prone gate)
kubectl get pods -n backstage
# Expected: backstage-<hash> Pod, Running, ~60-90s after Application syncs
# If CrashLoopBackOff:
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=80

# Gate 2: Catalog API
kubectl port-forward -n backstage svc/backstage 7007:7007 &
sleep 3
curl -s http://localhost:7007/api/catalog/entities | python3 -c "import sys,json; print(len(json.load(sys.stdin)))"
# Expected: integer >= 0  (chart-default catalog is small; 0 with overrides is also fine)

# Gate 3: UI loads
# Browser: http://localhost:7007
# Click Catalog → should render the default entries
```

If Path B: watch the recording. Score what you see.

### Score Phase 4

**Usability score for Backstage will be low.** That's not a failing — it's honest. The workshop image has a small static catalog and no working software templates. Production Backstage requires a custom-built image with org-specific catalog providers, plugins, and templates. That gap — *installed-but-not-shippable* — is the talk's closing line.

Known trap (from the skill file): the Backstage chart has no default image; `backstage.image.repository` and `tag` must be set. The workshop image is `ghcr.io/backstage/backstage:1.30.2` (the upstream image's last tagged release). The required `backstage.appConfig.kubernetes.clusterLocatorMethods: []` override prevents a startup crash.

---

## Wrap-up (5 min)

Total your scorecard:

| Row | Install | Integration | Usability | Cycles | AI time |
|---|---:|---:|---:|---:|---:|
| ArgoCD bootstrap | | | | | |
| Kyverno install | | | | | |
| Kyverno policies | | | | | |
| kube-prometheus-stack | | | | | |
| Backstage | | | | | |
| **Average** | | | | | |

For the wrap-up reflection (one question, once):

- **Manual time estimate:** if you'd built the same stack by hand (no AI), your honest guess for how long it would have taken — hours? days?
- **Did AI shift the toil?** No / Partial / Yes. One sentence on which phase felt most/least like babysitting.
- **Usability rating (1–10):** could you actually deploy a service through this platform tomorrow morning? What's the single biggest barrier?
- **Where AI helped most.** One specific moment.
- **Where AI struggled.** One specific failure pattern.
- **One thing you'll take back to your team.**

For comparison, the kubeauto reference build (single experienced engineer, overnight, no time pressure, 7 phases, 27 components) took **3 hours 10 minutes of AI time** with a **73.8% net toil reduction** and a **41% zero-correction rate**. The workshop run-of-the-day is a 4-component subset under live pressure with audience watching — your numbers will be different. **The variance is the data.** The closing slide compares yours to the reference and asks: what does the gap tell you about where AI actually helps?

### What you take home

- **Your scorecard.** Honest numbers across however many phases we landed.
- **The methodology.** Spec + skills + test gates + three-dimension scoring. Apply it to whatever you're building Monday.
- **The reference build.** [`github.com/peopleforrester/kubeauto-ai-day`](https://github.com/peopleforrester/kubeauto-ai-day) — 7 phases, 27 components, full scorecard. The "alone overnight" baseline to compare against.
- **The framework underneath.** [`github.com/peopleforrester/agentic-covenants`](https://github.com/peopleforrester/agentic-covenants) — the prevention-first matrix the Kyverno policies in this workshop are server-side enforcement cells of.

### After the workshop

**Your cluster is destroyed shortly after the session ends.** Up to 15 attendees can keep theirs for ~1 additional hour if you want to keep exploring; flag Michael during the closing 5 minutes or after the wrap. Save anything you want to keep (Grafana screenshots, manifests Claude generated) before you walk out.

**This repository stays public and bookmarkable.** Everything you saw today — the playbook, the spec, the GitOps source, the scorecard template, the framework reference — lives at [github.com/peopleforrester/KCD_Texas_2026_Workshop](https://github.com/peopleforrester/KCD_Texas_2026_Workshop). Fork it; extend it; reference it freely.

**Your scorecard is yours.** If you're willing to share it for the post-workshop aggregation (anonymized — no names, no cluster IDs in the published version), drop the filled file as `scorecard.md` in a fork or send it via the channel on the closing slide. Or keep it private. The personal-reflection value is the point either way.

**Where to ask follow-on questions:** open an Issue on this repository.

---

## If something is really stuck

**Michael is alone** — there are no TAs. Once Phase 1 starts he's driving Claude on the projector; he can't break away to debug individual clusters mid-build. Triage paths:

1. **During the setup window before T+0:** flag Michael by raising your hand. Cluster swaps happen here (30-second handoff from his pocket-spare credentials) or never.
2. **After Phase 1 starts, if your cluster is broken:** you're an observer for the rest of the build. Still take notes; still score what you see Claude do on the projector. The methodology lesson lands either way.
3. **If you fall behind on a phase but your cluster is fine:** run `/build-phase N` in your own Claude on whatever phase the room is currently on. Claude reads each phase spec independently — you'll catch up.
4. **Don't try to fix infrastructure from scratch.** The point of the workshop is to use Claude Code on a working substrate. Lost time on the substrate is lost time on the methodology.

If Phase 4 faceplants — *especially* in front of the whole room when Michael drives it — **that's the talk title.** "AI Ate My Implementation. Let's Build a Platform Together and Score What's Left." Score it honestly. The failure is the data.
