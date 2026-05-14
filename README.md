# KCD Texas 2026 — "The 90-Minute IDP"

**Friday, May 15, 2026** · 10:30 AM CDT · Room 3 · KCD Texas
**[The 90-Minute IDP: AI Ate My Implementation. Let's Build a Platform Together and Score What's Left.](https://kcd-texas-2026.sessionize.com/session/1149914)**

A 90-minute hands-on workshop. **Presenter-led, audience follows along.** Michael drives Claude Code live on stage with a build spec; ~60 attendees run the same prompts against their own pre-provisioned EKS clusters using Claude Code on their laptops. Real CNCF projects, real test gates, real scorecard. Implementation layer is supposedly disappearing — let's see what's left.

![Day-of workflow](assets/day-of-workflow.svg)

---

## The model

Three artifacts make this work. They're how the methodology is replicable on Monday morning for whatever you're building.

| Artifact | Lives at | Role |
|---|---|---|
| **The spec** | [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md) + [`spec/phases/`](spec/phases/) | The plain-Markdown source-of-truth Michael hands Claude on stage. Seven phases, 27 components, target manifests, completion criteria. |
| **The skills** | [`.claude/skills/`](.claude/skills/) | Current-version patterns Claude reads before generating each component. One per CNCF project — ArgoCD, Kyverno, kube-prometheus-stack, Backstage. Auto-loaded when `claude` runs from this repo root. |
| **The test gates** | Per-phase `kubectl` blocks in [`spec/phases/`](spec/phases/) | Reliable checks that a phase actually worked. Not pytest, not synthetic. Just `kubectl get pods`, `kubectl run`, `curl localhost:7007`. |

Plus a scorecard with three dimensions ([`scorecard/`](scorecard/)). Install, Integration, Usability — scored independently. The variance between dimensions across phases is what the talk hangs on.

**How far we get is how far we get.** Seven phases / 27 components in 90 minutes is aspirational; completion is not the point. Demonstrating the spec-driven methodology and producing honest scorecard data is.

---

## Where to start

**If you're presenting this on May 15:**
Read **[`spec/PRESENTER-RUNBOOK.md`](spec/PRESENTER-RUNBOOK.md)** end-to-end. It's the T-30-through-T+90 run sheet — pre-room setup, the literal opening words ([`spec/OPENING-SCRIPT.md`](spec/OPENING-SCRIPT.md)), the single-paste autonomous workflow that drives the whole 90 minutes, the Path A / Path B decision for Phase 4, what-can-go-wrong, and the rehearsal checklist at the bottom. Do the rehearsal once before the day. Before any cluster work, run `bash scripts/dry-run-validate.sh .` and expect a clean pass.

**If you're an attendee at the workshop:**
Open **[`kcd-tx-attendee-playbook.md`](kcd-tx-attendee-playbook.md)** and start at *"Before You Start."* You'll claim your cluster credentials from a QR code at the door → web app at https://bubbly-harmony-production-574d.up.railway.app/. Six commands from there gets you to a working `claude` session. From there you mirror Michael's prompts, run the same gate commands he runs, and score your own card. Michael is solo — no TAs — so use the setup window before T+0 to flag any cluster problems; once the build starts you're driving your own Claude.

**If you're reviewing this beforehand** (Accenture, organizers, replicators):
Read **[`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md)** (~120 lines, this is the spec) → **[`spec/OPENING-SCRIPT.md`](spec/OPENING-SCRIPT.md)** (what Michael says first) → one phase file like [`spec/phases/phase-02-gitops.md`](spec/phases/phase-02-gitops.md) to see the build/diff/gate/score pattern in detail. The [`spec/PRESENTER-RUNBOOK.md`](spec/PRESENTER-RUNBOOK.md) is the operational sequence on top.

**If you're running your own version of this workshop:**
Repo is MIT-licensed. Fork freely. Engineer-facing setup is in **[`kcd-texas-lab-setup-guide.md`](kcd-texas-lab-setup-guide.md)** and the Terraform + provisioning scripts under **[`kcd-texas-provisioning/`](kcd-texas-provisioning/)**. Student IAM lifecycle scripts in **[`scripts/`](scripts/)**.

**If you want the framework underneath:**
The Kyverno policies + admission controls students see today are server-side enforcement controls in the **Agentic Covenants** framework — a prevention-first matrix for autonomous-agent governance. Source-of-truth: **[github.com/peopleforrester/agentic-covenants](https://github.com/peopleforrester/agentic-covenants)**.

---

## What's in here

| Path | Purpose |
|---|---|
| [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md) | The spec Michael hands Claude on stage. 90 lines. Plain Markdown. |
| [`spec/OPENING-SCRIPT.md`](spec/OPENING-SCRIPT.md) | 60-second opener + 5-minute methodology framing + closing script. |
| [`spec/PRESENTER-RUNBOOK.md`](spec/PRESENTER-RUNBOOK.md) | T-30 to T+90 run sheet, what-can-go-wrong, rehearsal checklist. |
| [`spec/phases/`](spec/phases/) | Per-phase presenter voice: prompts, kubectl gates, known failure modes. |
| [`.claude/skills/`](.claude/skills/) | Current-version patterns auto-loaded into Claude (4 skills, one per component). |
| [`.claude/commands/`](.claude/commands/) | `/build-phase N` (catch-up / fallback for a single phase), `/score-component <name>`, `/validate-phase N` slash commands. Primary workflow is single-paste autonomous execution from [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md). |
| [`tests/`](tests/) | Pytest test gates per phase. Real `kubectl` calls, no mocks. Run during the build via `/build-phase` and during rehearsal via `pytest tests/test_phase_0N_*.py -v`. |
| [`.pre-commit-config.yaml`](.pre-commit-config.yaml) | Local pre-commit hooks: gitleaks (secrets), yamllint, kubeconform (K8s schema), helm-lint, shellcheck, dry-run validator on pre-push, conventional commit format. |
| [`spec/BRANCH-WORKFLOW.md`](spec/BRANCH-WORKFLOW.md) | Single-maintainer staging→main workflow doc. |
| [`.claude/hooks/`](.claude/hooks/) | Stop hook keeps Claude on-phase until the gate passes. |
| [`gitops/`](gitops/) | Pre-committed ground-truth GitOps source. ArgoCD on every student cluster reconciles from this directory. |
| [`scorecard/SCORECARD-TEMPLATE.md`](scorecard/SCORECARD-TEMPLATE.md) | Per-attendee scorecard (7 phase rows × Install / Integration / Usability + wrap-up reflection). |
| [`scorecard/PRESENTER-SCORECARD.md`](scorecard/PRESENTER-SCORECARD.md) | Live on-stage scorecard the audience watches fill in real time. |
| [`kcd-tx-attendee-playbook.md`](kcd-tx-attendee-playbook.md) | Attendee-facing preflight, connection card, follow-along guide, troubleshooting. |
| [`kcd-texas-lab-setup-guide.md`](kcd-texas-lab-setup-guide.md) | Engineer-facing setup guide — how the labs are provisioned end-to-end. |
| [`kcd-texas-provisioning-README.md`](kcd-texas-provisioning-README.md) | Cluster-provisioning detail (Terraform + EKS, cost breakdown). |
| [`kcd-texas-provisioning/`](kcd-texas-provisioning/) | Terraform modules + cluster lifecycle scripts. |
| [`scripts/`](scripts/) | Student IAM + the dry-run validator. |
| [`assets/`](assets/) | Mermaid diagram sources + rendered SVGs. |
| [`lab-requirements-may-2026-events.md`](lab-requirements-may-2026-events.md) | Lab spec across the May 2026 speaking events. |

## Repo layout

```
.
├── spec/                                  # Presenter-facing spec, runbook, phase scripts
│   ├── BUILD-SPEC.md                      # The spec handed to Claude on stage
│   ├── OPENING-SCRIPT.md                  # Opening words + framing slides + close
│   ├── PRESENTER-RUNBOOK.md               # 90-min run sheet
│   └── phases/
│       ├── phase-01-foundation.md        # assert pre-provisioned cluster
│       ├── phase-02-gitops.md             # ArgoCD + app-of-apps → 21 children
│       ├── phase-03-security.md           # Kyverno, Falco family, ESO, RBAC, NetPol
│       ├── phase-04-observability.md      # Prom/Grafana/OTel/LGTM
│       ├── phase-05-portal.md             # Backstage (Path A live / Path B recorded)
│       ├── phase-06-integration.md        # end-to-end cross-component flows
│       └── phase-07-hardening.md          # cert-manager, ResourceQuotas, PDBs
├── .claude/                               # Claude Code instrumentation
│   ├── skills/                            # argocd, kyverno, kube-prometheus-stack, backstage
│   ├── commands/                          # /build-phase, /score-component, /validate-phase
│   ├── hooks/cc-stop-deterministic.sh     # Holds Claude on-phase until PHASE_N_DONE
│   └── settings.json
├── gitops/                                # Pre-committed ground truth (ArgoCD source)
│   ├── bootstrap/app-of-apps.yaml         # Root Application
│   ├── apps/                              # 5 child Applications (with sync waves)
│   └── manifests/                         # ClusterPolicies, ServiceMonitors
├── scorecard/                             # Per-attendee + presenter scorecards
├── scripts/                               # IAM lifecycle + dry-run-validate.sh
├── kcd-texas-provisioning/                # Terraform + cluster lifecycle scripts
├── assets/                                # Diagrams
├── kcd-tx-attendee-playbook.md          # Attendee follow-along guide
├── kcd-texas-lab-setup-guide.md           # Engineer-facing setup runbook
├── kcd-texas-provisioning-README.md       # Cluster provisioning detail
├── lab-requirements-may-2026-events.md
├── README.md                              # This file
├── CLAUDE.md                              # Project notes for Claude Code agents
└── LICENSE                                # MIT
```

## Branch workflow

Working branch is `staging`. Changes land on `staging` first; promoted to `main` only after verification.

```bash
git checkout staging
git pull origin staging
# ... make changes ...
bash scripts/dry-run-validate.sh .       # expect 45/45 pass before pushing
git push origin staging
```

## Sibling repos

- **[github.com/peopleforrester/agentic-covenants](https://github.com/peopleforrester/agentic-covenants)** — the framework this workshop is a worked example of. Source of truth for the Agentic Covenants matrix.
- **[github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day)** — the same 7-phase reference build (~10 hours overnight, from-zero terraform-apply). The workshop attempts the same 7-phase / 27-component build in 90 minutes against a pre-provisioned cluster. Contains the 27-component scorecard the closing slide compares against.

## License

[MIT](LICENSE) — fork it, run it, modify it. Attribution appreciated.

## Contact

**Michael Forrester** — provisioning lead and presenter.
Open an Issue on this repository for follow-on questions after the workshop.
