# KCD Texas 2026 — "The 90-Minute IDP"

**Friday, May 15, 2026** · 10:30 AM CDT · Room 3 · KCD Texas

**[AI Ate My Implementation. Let's Build a Platform Together and Score What's Left.](https://kcd-texas-2026.sessionize.com/session/1149914)**

You'll spend 90 minutes building a production-style Internal Developer Platform on a real Kubernetes cluster — using Claude Code as your hands — and you'll score what AI does honestly across three dimensions while you do it.

## What you'll build

A 90-minute hands-on workshop where **you** build a working IDP using Claude Code. Seven phases, 27 components, real CNCF projects — ArgoCD, Kyverno, Falco, kube-prometheus-stack, Backstage, OpenTelemetry, cert-manager — real test gates, real scorecard.

The workshop's central question: as AI ate the implementation layer, what's left for engineers? You'll have data to answer it by the end.

## The 7 phases

You'll go through these in order. Each ends with a `<promise>PHASE_N_DONE</promise>` only when its pytest gate actually passes.

1. **Foundation** — cluster preflight. The only thing manually installed at this step is metrics-server (neither environment ships it).
2. **GitOps Bootstrap** — install ArgoCD, apply the app-of-apps; ArgoCD then fans out **32 child Applications** in sync-wave order in parallel. The rest of the workshop is mostly watching Healthy land and scoring.
3. **Security Stack** — Kyverno + 3 ClusterPolicies, Falco + custom rules + Falcosidekick + FalcoTalon (auto-remediation), External Secrets Operator, RBAC, NetworkPolicies.
4. **Observability** — kube-prometheus-stack (Prometheus + Grafana + operator + kube-state-metrics + node-exporter) + OpenTelemetry Collector + Loki + Promtail + Tempo + ArgoCD ServiceMonitors.
5. **Developer Portal** — Backstage, with the `appConfig` override that prevents the Kubernetes-plugin startup crash on the upstream image (`ghcr.io/backstage/backstage:1.30.2`).
6. **Integration** — cross-component verification: ArgoCD drift selfHeal, admission-event → metrics, Falco → FalcoTalon end-to-end auto-response.
7. **Hardening** — cert-manager + ClusterIssuers, ResourceQuotas, PodDisruptionBudgets.

## How the workshop runs

Presenter-led, you follow along. The presenter drives Claude Code on the projector with the same spec you're running on your cluster. You score what your Claude produces on a scorecard with three dimensions per phase:

- **Install** — did the component come up Healthy on the first try?
- **Integration** — does it work *with* the other components end-to-end?
- **Usability** — could a developer on your team drive this Monday morning?

Whatever doesn't land in 90 minutes, you finish on the plane home with the same spec. Completion isn't the point; the methodology and the scorecard data are.

## Getting started — pick your path

Two paths to a working `claude` session in the workshop repo. Same workshop, same spec, same scorecard.

### Path A — Terminal (AWS EKS cluster)
You'll need **Claude Code**, **AWS CLI**, **kubectl**, and **git** installed locally before the day. Scan the QR on slide 1 → enter your email at the registration site → get cluster credentials. **~10 slots.**

### Path B — Browser (KodeKloud)
No local installs required. Open the KodeKloud course in your browser — you get a 3-node kubeadm cluster + a terminal already authenticated, all in the page. **~50+ slots.**

Both paths converge at `claude` running in the cloned workshop repo. Full setup walkthrough — credentials, six commands, troubleshooting, what to do if the page doesn't load — is in **[kcd-tx-attendee-playbook.md](kcd-tx-attendee-playbook.md)**.

## The three artifacts (and why you can use them Monday)

The methodology is replicable for whatever your team is building. Three artifacts make it work, plus a scorecard:

| Artifact | Lives at | What it does |
|---|---|---|
| **The spec** | [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md) | Plain Markdown, ~120 lines. Tells Claude what to build, in what order, with what stack pins. Single-paste autonomous execution. |
| **The skills** | [`.claude/skills/`](.claude/skills/) | Current-version patterns Claude reads before generating each component. One per CNCF project. Auto-loaded when `claude` runs from the repo root. |
| **The test gates** | [`tests/`](tests/) | Pytest assertions that a phase actually worked. Real `kubectl` calls, no mocks. No promise without a green gate. |
| **The scorecard** | [`scorecard/SCORECARD-TEMPLATE.md`](scorecard/SCORECARD-TEMPLATE.md) | Three dimensions × 7 phases. You fill it in real time. |

The variance between Install / Integration / Usability across phases is the data the closing slide hangs on.

## What to do during the workshop

1. **Get to a working `claude` session** in the workshop repo (per the path you picked above).
2. **Mirror the presenter's prompts** as they're run on the projector. Same prompt, your cluster.
3. **Watch your scorecard fill in** as each phase lands or fails. Use [`scorecard/SCORECARD-TEMPLATE.md`](scorecard/SCORECARD-TEMPLATE.md) — printed card optional.
4. **Score honestly.** Empty rows and failures are data. A 4/10 Install with a frank reason beats a faked 9/10.
5. **Compare with the room at the end.** Variance between paths and within phases is what the talk hangs on.

The attendee playbook ([kcd-tx-attendee-playbook.md](kcd-tx-attendee-playbook.md)) has the full setup-through-wrap-up walkthrough.

## Workshop materials

- **[kcd-tx-attendee-playbook.md](kcd-tx-attendee-playbook.md)** — attendee setup + follow-along + troubleshooting
- **[scorecard/SCORECARD-TEMPLATE.md](scorecard/SCORECARD-TEMPLATE.md)** — your personal scorecard, fill as you go
- **[spec/BUILD-SPEC.md](spec/BUILD-SPEC.md)** — the spec you'll watch get pasted into Claude
- **[.claude/skills/](.claude/skills/)** — the current-version patterns Claude auto-loads (read these later if you want to see how skill files are written)
- **[demo/](demo/)** — terminal scripts (one per workshop component) with bright ACCESS / DENY / SUCCESS / FAILURE badges, useful for verifying any single component is running

## What you take home

The cluster gets destroyed an hour after the workshop ends. What goes home with you:

1. **Your filled scorecard** — honest numbers across however many phases landed
2. **The methodology** — spec + skills + gates + three-dimension scorecard, applicable to anything you build with AI on Monday
3. **The full 27-component spec** — battle-tested. Run it overnight on your own cluster and land all 27 in ~3 hours
4. **A reference comparison** — [github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day) ran the same spec overnight without time pressure; the variance between today's "live under pressure" and that "alone overnight" is the closing slide

## For instructors and replicators

Running this workshop yourself, or evaluating it before the day? See **[INSTRUCTOR.md](INSTRUCTOR.md)** for the presenter run sheet, opening script, provisioning scripts, dry-run validator usage, and replication notes.

## License

[MIT](LICENSE) — fork it, run it, modify it. Attribution appreciated.

## Contact

Open an issue on this repository for follow-on questions after the workshop.
