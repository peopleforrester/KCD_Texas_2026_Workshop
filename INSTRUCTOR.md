# Instructor Guide

> **This file is for instructors running this workshop. Attendees should read [README.md](README.md) and [kcd-tx-attendee-playbook.md](kcd-tx-attendee-playbook.md) instead.**

If you're running "The 90-Minute IDP" as a presenter — at KCD Texas 2026, at a re-run, or as a fork for your own event — this is your run sheet.

---

## Day-of workflow (operator timeline)

![Day-of workflow](assets/day-of-workflow.svg)

Three phases on the operator timeline: pre-event provisioning (the night before or morning of), day-of presenter execution (the 90 minutes themselves), post-event teardown (immediately after). The diagram shows the operator's path, not the attendee's; attendees see only the day-of slice.

## If you're presenting this on workshop day

Read **[`spec/PRESENTER-RUNBOOK.md`](spec/PRESENTER-RUNBOOK.md)** end-to-end. It's the T-30-through-T+90 run sheet:

- Pre-room setup (laptop / projector / spare credentials in your pocket)
- The literal opening words ([`spec/OPENING-SCRIPT.md`](spec/OPENING-SCRIPT.md))
- The single-paste autonomous workflow that drives the whole 90 minutes
- The Path A / Path B decision for Phase 5 (Backstage)
- What-can-go-wrong, in priority order
- The rehearsal checklist at the bottom

**Before the day:** run the rehearsal checklist at least once against a real cluster.
**Before any cluster work or push:** run `bash scripts/dry-run-validate.sh .` from the repo root — expect a clean pass.

## If you're reviewing this beforehand (organizers, replicators, lab providers)

Read in this order:

1. **[`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md)** (~120 lines) — the spec the presenter hands to Claude on stage. Seven phases, 27 components, the single-paste autonomous-execution model.
2. **[`spec/OPENING-SCRIPT.md`](spec/OPENING-SCRIPT.md)** — the literal opening words and methodology framing slides.
3. One phase file, e.g. **[`spec/phases/phase-02-gitops.md`](spec/phases/phase-02-gitops.md)** — to see the build/diff/gate/score pattern in detail.
4. **[`spec/PRESENTER-RUNBOOK.md`](spec/PRESENTER-RUNBOOK.md)** — the operational sequence on top.

## If you're running your own version

The repo is MIT-licensed. Fork freely.

- **Engineer-facing setup:** [`kcd-texas-lab-setup-guide.md`](kcd-texas-lab-setup-guide.md) describes how the labs are provisioned end-to-end.
- **Cluster provisioning:** [`kcd-texas-provisioning/`](kcd-texas-provisioning/) — Terraform modules under `terraform/`, plus the batch scripts (`batch-provision.sh`, `batch-teardown.sh`, `post-provision-setup.sh`, `teardown.sh`) and the IAM policy JSON.
- **Attendee IAM lifecycle:** [`scripts/create-attendee-users.sh`](scripts/create-attendee-users.sh), [`scripts/delete-attendee-users.sh`](scripts/delete-attendee-users.sh), [`scripts/create-permissions-boundary.sh`](scripts/create-permissions-boundary.sh).
- **Credential distribution app:** lives in a sibling repo, `../kcd-website/`, deployed to Railway. Reads a `pool.csv` of cluster credentials and atomically hands one per attendee email submission.

For overflow planning (e.g., late-add of 40 more clusters in a fresh AWS account), see **[`docs/PLAN-overflow-accen-dev.md`](docs/PLAN-overflow-accen-dev.md)**.

## Dry-run validator

`scripts/dry-run-validate.sh` is a static, no-cluster-needed sanity check. It verifies:

- All required files exist (specs, skills, tests, scorecards, etc.)
- YAML parses across the `gitops/` tree
- Pinned chart versions still exist upstream
- Each Application's `helm.valuesObject` renders cleanly via `helm template`
- Sync waves match between `gitops/apps/` and what skill files say

Run it before any push, especially before a `staging → main` fast-forward. Expect a clean pass (64/64 at time of writing).

## Branch workflow

Working branch is `staging`. All changes land on `staging` first; `main` is promoted only after `staging` is verified.

```bash
git checkout staging
git pull origin staging
# ... make changes ...
bash scripts/dry-run-validate.sh .       # expect all checks pass
git push origin staging
# Then, after verification:
git checkout main && git merge --ff-only staging && git push origin main
```

**ArgoCD reads from `main`** on every attendee cluster, so anything not yet promoted from `staging` won't reach the workshop fleet.

## Sibling repos

- **`../kcd-website/`** — Flask app at [bubbly-harmony-production-574d.up.railway.app](https://bubbly-harmony-production-574d.up.railway.app/). Hands attendees their cluster credentials from a pool.csv. Deployed on Railway; not in this repo's git tree.
- **[github.com/peopleforrester/agentic-covenants](https://github.com/peopleforrester/agentic-covenants)** — the framework this workshop is a worked example of. Source of truth for the Agentic Covenants prevention-first matrix for autonomous-agent governance.
- **[github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day)** — the same 7-phase reference build run overnight (~10 hours, from-zero terraform-apply). The workshop attempts the same 27-component build in 90 minutes against a pre-provisioned cluster. The closing slide compares both scorecards.

## Repo layout (instructor perspective)

```
.
├── spec/                                  # Presenter-facing spec, runbook, phase scripts
│   ├── BUILD-SPEC.md                      # The spec handed to Claude on stage (you paste this)
│   ├── OPENING-SCRIPT.md                  # Opening words + framing slides + close
│   ├── PRESENTER-RUNBOOK.md               # 90-min run sheet
│   └── phases/                            # Per-phase prompts, gates, known failure modes
├── .claude/                               # Claude Code instrumentation (auto-loaded for both you and attendees)
│   ├── skills/                            # current-version patterns Claude reads before generating
│   ├── commands/                          # /build-phase (catch-up), /score-component, /validate-phase
│   ├── hooks/cc-stop-deterministic.sh     # currently inactive; preserved as dead code
│   └── settings.json
├── gitops/                                # Pre-committed ground truth (ArgoCD source)
│   ├── bootstrap/app-of-apps.yaml         # Root Application
│   ├── apps/                              # 32 Applications: 22 platform + 10 demo (sync waves)
│   └── manifests/                         # ClusterPolicies, ServiceMonitors, namespaces, etc.
├── scorecard/
│   ├── SCORECARD-TEMPLATE.md              # Per-attendee scorecard (also linked from README)
│   └── PRESENTER-SCORECARD.md             # The live on-stage scorecard you fill on the projector
├── scripts/                               # Attendee IAM lifecycle + dry-run-validate.sh
├── kcd-texas-provisioning/                # Terraform + cluster lifecycle scripts
├── kcd-texas-lab-setup-guide.md           # Engineer-facing setup runbook (end-to-end provisioning)
├── kcd-texas-provisioning-README.md       # Cluster-provisioning detail (cost breakdown, Terraform)
├── lab-requirements-may-2026-events.md    # Lab spec across the May 2026 speaking events
├── docs/                                  # Plans + reference docs (e.g., overflow-provisioning)
├── assets/                                # Mermaid sources + rendered SVGs
├── demo/                                  # Terminal demo scripts (one per workshop component, brightly badged)
├── tests/                                 # Per-phase pytest test gates (real kubectl, no mocks)
├── kcd-tx-attendee-playbook.md            # Attendee follow-along guide (the thing you point them at)
├── README.md                              # Student-facing landing page
├── INSTRUCTOR.md                          # This file
├── CLAUDE.md                              # Project notes for Claude Code agents
└── LICENSE                                # MIT
```

## License

[MIT](LICENSE) — fork it, run it, modify it. Attribution appreciated.

## Contact

**Michael Forrester** — provisioning lead and presenter.
Open an issue on this repository for follow-on questions after the workshop.
