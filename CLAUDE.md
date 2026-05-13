# Project Notes

This repository holds the workshop materials and provisioning automation for **"The 90-Minute IDP"** at **KCD Texas 2026 (May 15, 2026)**. ~60 attendees, each with their own pre-provisioned EKS cluster. **Presenter-led with audience follow-along** — Michael drives Claude Code live on stage; students mirror prompts on their own clusters. The workshop has a hard date — correctness and timely readiness matter more than refactoring.

The workshop is a worked example of one column of the **Agentic Covenants** framework (Michael's prevention-first matrix for autonomous-agent governance). Source of truth for the framework lives at [github.com/peopleforrester/agentic-covenants](https://github.com/peopleforrester/agentic-covenants); do not duplicate framework content here, only reference it. The Kyverno policies in `gitops/manifests/kyverno-policies/` are server-side enforcement controls in the Authorization and Blast-radius rows of the matrix.

## Layout

### Presenter-facing spec

- `spec/BUILD-SPEC.md` — the spec Michael hands Claude on stage. 90 lines. Plain Markdown. Lists the 4 phases, the 3 scoring dimensions, the stack pins, the gate-pass promise format (`<promise>PHASE_N_DONE</promise>`).
- `spec/OPENING-SCRIPT.md` — 60-second slide-1 opener (literal words to read), 5-minute pre-build framing (3 slides), closing script.
- `spec/PRESENTER-RUNBOOK.md` — T-30 (pre-room) through T+90 (wrap-up) sequence, per-phase pacing, the Path A / Path B decision for Phase 4, what-can-go-wrong priority list, rehearsal checklist.
- `spec/phases/phase-0[1-4]-*.md` — per-phase presenter voice: the literal prompt Michael pastes, the test gate commands, the known failure modes Claude tends to fall into without the skill file. Each phase's "Known failure modes" section is the script for narrating when a gate fails live.

### Claude Code instrumentation (auto-loaded when `claude` runs from this repo root)

- `.claude/skills/argocd-patterns.md` — chart 9.x → ArgoCD 3.x line; `configs.cm` (not `configs.params`) for timeout.reconciliation; annotation-based tracking default; sync wave conventions.
- `.claude/skills/kyverno-policies.md` — chart 3.8.0; webhook `namespaceSelector` as a map (not list); `ServerSideApply=true` for the policies Application.
- `.claude/skills/kube-prometheus-stack.md` — chart 84.5.0; `ServerSideApply=true` mandatory (CRDs exceed annotation size limit); alertmanager disabled for workshop pacing.
- `.claude/skills/backstage-templates.md` — chart 2.7.0; **two traps**: (1) chart has no default image (workshop uses `ghcr.io/backstage/backstage:1.30.2`), (2) the upstream image's baked-in app-config initializes the Kubernetes plugin and crashes without a cluster locator — `backstage.appConfig` override required (verified live on 2026-05-13). An earlier draft pointed at `roadiehq/community-backstage-image:1.50.4` which does not exist anywhere (HTTP 404 on GHCR, Docker Hub repo abandoned 2021) — don't go back to it.
- `.claude/commands/build-phase.md` — defines `/build-phase N`. Read context → walk through architecture → generate manifest to `~/my-<component>.yaml` → diff against ground truth in `gitops/apps/` → narrate the diff → read out the test gate commands → emit `<promise>PHASE_N_DONE</promise>` when the gate passes.
- `.claude/commands/score-component.md` — `/score-component <name>` walks Install / Integration / Usability for one row.
- `.claude/commands/validate-phase.md` — `/validate-phase N` runs the test gate and diagnoses against the phase's known risks.
- `.claude/hooks/cc-stop-deterministic.sh` + `.claude/settings.json` — workshop stop hook. Blocks Claude from exiting a `/build-phase` until the phase emits `<promise>PHASE_N_DONE</promise>`. Inactive unless the marker file `.build-active` exists.

### Ground truth GitOps source

- `gitops/bootstrap/app-of-apps.yaml` — root Application Michael `kubectl apply`s in Phase 1 after Helm-installing ArgoCD. Points at `gitops/apps/` on `main` of this repo. All student clusters reconcile from the same canonical manifests.
- `gitops/apps/` — five child Applications with sync waves: kyverno (-5), kyverno-policies (-4), kube-prometheus-stack (1), argocd-servicemonitors (2), backstage (5).
- `gitops/manifests/kyverno-policies/` — three ClusterPolicy YAMLs (require-labels, require-resource-limits, disallow-privileged), all enforce-mode, scoped to the `apps` namespace.
- `gitops/manifests/argocd-servicemonitors/` — three ServiceMonitor manifests for ArgoCD's server, application-controller, and repo-server. Wave 2 so they apply *after* kube-prometheus-stack (wave 1) registers the ServiceMonitor CRD. Verified-correct selectors and port name (`http-metrics`, `app.kubernetes.io/name=argocd-server-metrics` etc., per `helm template` of the actual chart — not what you'd guess from the Service names).
- **Workshop model:** students do not push to git. They clone this repo read-only, paste the same prompts Michael pastes (or run `/build-phase` themselves to catch up), and watch their own cluster reconcile from these pre-committed manifests.

### Scorecards

- `scorecard/SCORECARD-TEMPLATE.md` — per-attendee scorecard. 4 phase rows × Install / Integration / Usability + AI time + correction cycles, plus a 6-question wrap-up reflection (manual-time estimate, toil-shifted question, usability rating, where AI helped/struggled, takeaway).
- `scorecard/PRESENTER-SCORECARD.md` — the live on-stage scorecard. Three dimensions per row, six rows across the four phases. Fills in real time on the projector while the audience fills in their own.

### Attendee + operator docs

- `kcd-texas-student-playbook.md` — attendee-facing preflight + connection-card example + follow-along guide + preflight troubleshooting. Aligned with the presenter-led model: attendees mirror Michael's prompts, score their own card, run `/build-phase N` themselves if they fall behind.
- `kcd-texas-lab-setup-guide.md` — engineer-facing setup runbook (the canonical "how it all works" doc for operators).
- `kcd-texas-provisioning-README.md` — cluster-provisioning detail (Terraform + EKS, cost breakdown).
- `lab-requirements-may-2026-events.md` — lab requirements across the May 2026 speaking events.
- `kcd-texas-provisioning/` — Terraform modules under `terraform/` + batch provision/teardown + IAM policy JSON. Note: scripts here handle cluster creation; the root `scripts/` directory handles student IAM lifecycle (different concern).
- `scripts/create-permissions-boundary.sh`, `create-student-users.sh`, `delete-student-users.sh` — student IAM lifecycle.
- `scripts/dry-run-validate.sh` — 45-check static validator (no cluster needed). Verifies file structure, chart versions exist upstream, every Application's `helm template` renders cleanly, sync waves match between specs and `gitops/apps/`, ArgoCD chart 9.x is current GA. Run before any cluster work or before pushing spec changes.
- `assets/` — Mermaid sources (`.mmd`) and rendered SVGs for the four core diagrams.

## Branch workflow

Default branch is `staging`. All work goes to `staging` first; promote to `main` only after verification. Run `bash scripts/dry-run-validate.sh .` before pushing to staging — expect 45/45.

## Architecture notes

- Single AWS account, all students share it.
- Each student gets a temporary IAM user with a permissions boundary that allowlists EKS and supporting services. Everything else is blocked by omission — no explicit denies needed.
- Cluster auth via EKS Access Entries (`authentication_mode = "API"`), not aws-auth ConfigMap. Migrated for reliability — see `kcd-texas-lab-setup-guide.md` "Kubernetes Access" section.
- One presenter cluster + 3 spares on top of the student count (60 students + 3 spares + 1 presenter = 64 clusters).
- Cluster spec: 3× t3.xlarge nodes, EKS 1.34, pre-created namespaces (`argocd`, `kyverno`, `monitoring`, `backstage`, `apps`, `sample-app`), and pre-pulled images for the workshop tools (tags pinned to match what `gitops/apps/*.yaml` deploys).
- Cost: ~$0.65/hr per cluster (EKS $0.10 + 3× t3.xlarge $0.50 + NAT $0.045 + EIP $0.005). 64 clusters × 3 hours ≈ $125.

## Live validation status (2026-05-13)

Full end-to-end walkthrough on a real EKS cluster (`kcd-texas-spec-validate`, us-east-2). All four phases verified:
- Phase 1: 5 child Applications discovered from app-of-apps, all reached Synced/Healthy in ~90s
- Phase 2: bad pod rejected (require-labels + require-resource-limits fired), good pod accepted, system pod allowed
- Phase 3: all 3 ArgoCD scrape targets `up` in Prometheus (verified ServiceMonitor selectors + `http-metrics` port name)
- Phase 4: Backstage pod Running 1/1, `/api/catalog/entities` returns entities, health probe `ok`

Bugs caught and fixed during validation: node group IAM role name_prefix > 38 chars; ServiceMonitor selectors wrong; Backstage image didn't exist; Backstage Kubernetes plugin crashed without appConfig override; YAML indentation put `appConfig` at root instead of under `backstage:`; Grafana version drift (12.3.0 → 13.0.1 actual).

Cluster torn down clean; cost ~$1.50 for the validation run.
