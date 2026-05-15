# Project Notes

This repository holds the workshop materials and provisioning automation for **"The 90-Minute IDP"** at **KCD Texas 2026 (May 15, 2026)**. ~60 attendees, each with their own pre-provisioned EKS cluster. **Presenter-led with audience follow-along** — Michael drives Claude Code live on stage; students mirror prompts on their own clusters. The workshop has a hard date — correctness and timely readiness matter more than refactoring.

The workshop is a worked example of one column of the **Agentic Covenants** framework (Michael's prevention-first matrix for autonomous-agent governance). Source of truth for the framework lives at [github.com/peopleforrester/agentic-covenants](https://github.com/peopleforrester/agentic-covenants); do not duplicate framework content here, only reference it. The Kyverno policies in `gitops/manifests/kyverno-policies/` are server-side enforcement controls in the Authorization and Blast-radius rows of the matrix.

---

## Source-of-truth rules (read this first if you're Claude Code running in this repo)

**This repo is canonical.** When `claude` starts from this repo root on a workshop attendee's laptop (or the presenter's), the auto-loaded skill files, the spec, the pre-committed `gitops/` tree, and the pytest gates are the authoritative reference for the entire workshop. They have all been live-validated against a real EKS cluster on 2026-05-13. Do not deviate from them unless explicitly instructed.

In particular:

1. **`gitops/` is the canonical Kubernetes state.** ArgoCD reconciles every student's cluster from `gitops/apps/` on `main`. When Phase 2 fans out the app-of-apps, every student's cluster receives the same 22 platform Applications + 10 demo workloads. Manifests Claude generates during the workshop go to `~/my-<component>.yaml` for **diffing purposes only** — they are educational artifacts, not deployable artifacts. Never push to `gitops/` from a workshop session.

2. **The pytest gates in `tests/test_phase_0[1-7]_*.py` are the only source of truth for "did this phase pass."** A `<promise>PHASE_N_DONE</promise>` requires `pytest tests/test_phase_0N_*.py -v` to exit 0. Not "most tests passed." Not "the cluster looks healthy." All tests pass, or `<promise>PHASE_N_FAILED</promise>` with notes. Honest failures > faked passes.

3. **The skill files in `.claude/skills/` encode current-version traps Claude tends to fall into.** Read the relevant skill file BEFORE generating any manifest, even if you think you already know how the chart works. Most public tutorials reference patterns from chart versions 2+ generations old; the skill files document what's correct *now*.

4. **The phase files in `spec/phases/phase-0N-*.md` describe what each phase does, including the prompt, the test gate, and known failure modes.** Read the phase file at the start of each phase. The "Known failure modes" section is your script for narrating when a gate fails live.

5. **Two specific traps are pre-fixed in the ground truth and live-validated. Do not regress them:**
   - **Backstage image:** must be `ghcr.io/backstage/backstage:1.30.2`. The image `roadiehq/community-backstage-image:1.50.4` does not exist anywhere (HTTP 404 on GHCR, Docker Hub abandoned 2021). Never use it.
   - **Backstage Kubernetes plugin:** the upstream image's baked-in app-config initializes the Kubernetes plugin, which crashes at startup with `Plugin 'kubernetes' startup failed; Kubernetes configuration is missing` unless a cluster locator is provided. `gitops/apps/backstage.yaml` includes a `backstage.appConfig` override (`kubernetes.serviceLocatorMethod: multiTenant` + `clusterLocatorMethods: []`) that prevents the crash. Watch for this in any generated Backstage manifest.

6. **Promise discipline applies to every phase.** No phase moves on without its promise. Faking a promise means a future phase fails for a reason that's harder to debug. The audience is watching the projector — a faked pytest output is visible.

7. **Read the spec before deviating.** If something seems off, the spec is more likely right than your instinct. The spec was live-validated; your instinct comes from training data that may be stale on these specific charts.

---

## Layout

### Presenter-facing spec

- `spec/BUILD-SPEC.md` — the spec Michael hands Claude on stage. **Single-paste autonomous execution for all 7 phases**, ~120 lines. Plain Markdown. Lists the 7 phases, the 3 scoring dimensions, the stack pins, the gate-pass promise format (`<promise>PHASE_N_DONE</promise>`).
- `spec/OPENING-SCRIPT.md` — 60-second slide-1 opener (literal words to read), pre-build framing slides, closing script.
- `spec/PRESENTER-RUNBOOK.md` — T-30 (pre-room) through T+90 (wrap-up) sequence, per-phase pacing, what-can-go-wrong priority list, rehearsal checklist.
- `spec/phases/phase-0[1-7]-*.md` — per-phase presenter voice: prompt, test gate, known failure modes. Each phase's "Known failure modes" section is the script for narrating when a gate fails live.
  - **Phase 1 — Foundation** (assert pre-provisioned cluster). No manifests generated.
  - **Phase 2 — GitOps Bootstrap** (ArgoCD + app-of-apps, fans out to 22 platform Apps + 10 demo workloads).
  - **Phase 3 — Security Stack** (Kyverno, Falco + falcosidekick + falco-talon, ESO, RBAC, NetworkPolicies).
  - **Phase 4 — Observability** (kube-prometheus-stack, Grafana dashboards, ArgoCD ServiceMonitors, OTel, Loki, Promtail, Tempo).
  - **Phase 5 — Developer Portal** (Backstage).
  - **Phase 6 — End-to-End Integration** (cross-component flows: drift detection, admission+metrics, audit trail).
  - **Phase 7 — Hardening** (cert-manager + Issuers, ResourceQuotas, PDBs).

### Claude Code instrumentation (auto-loaded when `claude` runs from this repo root)

- `.claude/skills/argocd-patterns.md` — chart 9.x → ArgoCD 3.x line; `configs.cm` (not `configs.params`) for timeout.reconciliation; annotation-based tracking default; sync wave conventions.
- `.claude/skills/kyverno-policies.md` — chart 3.8.0; webhook `namespaceSelector` as a map (not list); `ServerSideApply=true` for the policies Application.
- `.claude/skills/kube-prometheus-stack.md` — chart 84.5.0; `ServerSideApply=true` mandatory (CRDs exceed annotation size limit); alertmanager disabled for workshop pacing.
- `.claude/skills/backstage-templates.md` — chart 2.7.0; **two traps**: (1) chart has no default image (workshop uses `ghcr.io/backstage/backstage:1.30.2`), (2) upstream image's baked-in app-config crashes the Kubernetes plugin without a cluster locator — `backstage.appConfig` override required (verified live 2026-05-13).
- `.claude/skills/falco-rules.md` — Falco custom rules (CRITICAL-tagged) for credential access detection. Falcosidekick wiring to Prometheus.
- `.claude/skills/otel-wiring.md` — OTel Collector pipeline construction. `memory_limiter` MUST be first processor in every pipeline.
- `.claude/commands/build-phase.md` — `/build-phase N`, a **catch-up / fallback** for a single phase. Reads spec → skill → executes phase → runs pytest gate → emits `<promise>PHASE_N_DONE</promise>` or `_FAILED`. The **primary workflow** is single-paste autonomous execution from `spec/BUILD-SPEC.md`; this command is the per-phase fallback when the autonomous loop gets stuck or a student needs to catch up.
- `.claude/commands/score-component.md` — `/score-component <phase>` walks Install / Integration / Usability for one row.
- `.claude/commands/validate-phase.md` — `/validate-phase N` runs the pytest gate and diagnoses against the phase's known risks.
- `.claude/hooks/cc-stop-deterministic.sh` + `.claude/settings.json` — workshop stop hook. Blocks Claude from exiting until the phase emits its promise (`PHASE_[1-7]_DONE` or `ALL_PHASES_COMPLETE`). **Currently INACTIVE.** The hook was the enforcement mechanism for the older per-phase `/build-phase` flow; nothing creates the `.build-active` marker file anymore because the primary workflow is single-paste autonomous execution from `spec/BUILD-SPEC.md`. The script short-circuits to "approve" on every invocation today. Preserved as documented dead code in case `/build-phase` is reactivated.
- `tests/test_phase_0[1-7]_*.py` — 47 pytest test gates across 7 phase files. Real kubectl calls via `tests/conftest.py` fixtures, no mocks.
- `.pre-commit-config.yaml` — local pre-commit hooks: gitleaks, yamllint, kubeconform, helm-lint, shellcheck, dry-run validator on pre-push, conventional commit format. Run `pre-commit install` once to wire them up.
- `spec/BRANCH-WORKFLOW.md` — single-maintainer staging→main workflow doc. ArgoCD reads from `main`, edits land on `staging` first.

### Ground truth GitOps source

- `gitops/bootstrap/app-of-apps.yaml` — root Application Michael `kubectl apply`s in Phase 2 after Helm-installing ArgoCD. Points at `gitops/apps/` on `main` of this repo. All student clusters reconcile from the same canonical manifests.
- `gitops/apps/` — **32 Applications** total. **22 platform Applications:** kyverno, kyverno-policies, falco, falcosidekick, falco-talon, external-secrets, eso-resources, rbac, network-policies, namespaces, kube-prometheus-stack, grafana-dashboards, argocd-servicemonitors, otel-collector, loki, promtail, tempo, backstage, backstage-resources, cert-manager, cert-manager-issuers, resource-quotas. **10 demo workloads:** sample-app, ecom-api, ecom-frontend, ecom-worker, 5 party-apps (hedgehog, unicorn, spider, wombat, mantis-shrimp), load-generator.
- **Workshop model:** students do not push to git. They clone this repo read-only, paste the same prompt Michael pastes (or run `/build-phase` themselves to catch up), and watch their own cluster reconcile from these pre-committed manifests.

### Scorecards

- `scorecard/SCORECARD-TEMPLATE.md` — per-attendee scorecard. **7 phase rows** × Install / Integration / Usability + cycles + AI time, plus a 6-question wrap-up reflection.
- `scorecard/PRESENTER-SCORECARD.md` — the live on-stage scorecard. Three dimensions per row, **7 rows for 7 phases**. Fills in real time on the projector.

### Attendee + operator docs

- `kcd-tx-attendee-playbook.md` — attendee-facing preflight (QR → web app at https://bubbly-harmony-production-574d.up.railway.app/) + follow-along guide + preflight troubleshooting. **No paper-card fallback** — if the web app is down, the workshop is down.
- `kcd-texas-lab-setup-guide.md` — engineer-facing setup runbook.
- `kcd-texas-provisioning-README.md` — cluster-provisioning detail (Terraform + EKS, cost breakdown).
- `lab-requirements-may-2026-events.md` — lab requirements across the May 2026 speaking events.
- `kcd-texas-provisioning/` — Terraform modules + batch provision/teardown + IAM policy JSON.
- `scripts/create-permissions-boundary.sh`, `create-attendee-users.sh`, `delete-attendee-users.sh` — attendee IAM lifecycle (cluster + IAM-user naming convention: `kcd-tx-attendee-NN`).
- `scripts/dry-run-validate.sh` — static validator (no cluster needed). Verifies file structure, chart versions, render-cleanliness, sync waves. Run before any cluster work or before pushing spec changes.
- `demo/` — 18 brightly-colored terminal scripts (one per component) for live verification on stage. Each uses the current `kubectl` context, narrates every command, and emits ACCESS/DENY/SUCCESS/FAILURE badges.
- `assets/` — Mermaid sources (`.mmd`) and rendered SVGs for diagrams.

### Credential distribution (separate repo / Railway deploy)

- **`../kcd-website/`** — Flask app that hands attendees their cluster credentials. Lives at https://bubbly-harmony-production-574d.up.railway.app/. Reads `pool.csv` (cluster name + AWS keys + region per row), claims one atomically per email submission, shows a success page with AWS creds + the 6 setup commands + the pacing prompt to paste into Claude. The pacing prompt is the workshop's pacing brake — it tells Claude to process the spec one phase at a time and pause for scoring after each, instead of speed-running all 7 phases in 10 minutes.

## Branch workflow

Default branch is `staging`. All work goes to `staging` first; promote to `main` only after verification. Run `bash scripts/dry-run-validate.sh .` before pushing to staging.

## Architecture notes

- Single AWS account, all students share it.
- Each student gets a temporary IAM user with a permissions boundary that allowlists EKS and supporting services.
- Cluster auth via EKS Access Entries (`authentication_mode = "API"`), not aws-auth ConfigMap.
- One presenter cluster + 3 spares on top of the student count (60 students + 3 spares + 1 presenter = 64 clusters).
- Cluster spec: 3× t3.xlarge nodes, EKS 1.34, cluster comes up **barebones** — the 9 workshop namespaces (including the otherwise-empty `falco` namespace that holds FalcoTalon's leader-election Lease) are created by `gitops/apps/namespaces` at sync-wave -10 during Phase 2. Container images are pre-pulled where possible to speed first reconciliation.
- Cost: ~$0.65/hr per cluster. 64 clusters × 3 hours ≈ $125.

## Live validation status

**Workshop scope extended (2026-05-14)** from a 4-phase subset to the **full 7-phase / 27-component build** matching the kubeauto-ai-day reference. Live validation on `kcd-clust-1`:

- **47/47 pytest gates passing.**
- **32/33 ArgoCD Applications Healthy** (1 Degraded by design — ESO without IRSA, the central scorecard variance point).
- **11/11 demo Pods Running** in `apps` namespace.
- Wall-time on fresh ArgoCD: bootstrap → all 22 platform Apps discovered (~48 seconds); bootstrap → 19+ Apps Healthy (~5 minutes); pytest gate sweep (~4 minutes).

Bugs caught and fixed during validation: node group IAM role name_prefix > 38 chars; ServiceMonitor selectors wrong; Backstage image didn't exist; Backstage Kubernetes plugin crashed without appConfig override; YAML indentation put `appConfig` at root instead of under `backstage:`; Grafana version drift (12.3.0 → 13.0.1 actual); FalcoTalon leader-election Lease needs a `falco` namespace; chronic Kyverno CRD-description drift handled via `ignoreDifferences`. All fixed and verified.

The reference build (`kubeauto-ai-day`) took ~10 hours overnight to land the same 7-phase / 27-component stack from a from-zero terraform-apply. The workshop attempts the same build in 90 minutes against a pre-provisioned cluster. **How far we get is how far we get** is a load-bearing phrase, not a hedge.
