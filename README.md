![The 90-Minute IDP](assets/hero.png)

# The 90-Minute IDP

**A live workshop where an audience built a production-style Internal Developer Platform with Claude Code, then scored honestly what the AI actually left behind.**

Delivered at **[KCD Texas 2026](https://kcd-texas-2026.sessionize.com/session/1149914)** on Friday, 15 May 2026, Room 3.

[![Event](https://img.shields.io/badge/KCD_Texas-15_May_2026-0b7285)](https://kcd-texas-2026.sessionize.com/session/1149914)
[![Phases](https://img.shields.io/badge/phases-7-informational)](spec/BUILD-SPEC.md)
[![Components](https://img.shields.io/badge/CNCF_components-27-informational)](#what-got-built)
[![Applications](https://img.shields.io/badge/ArgoCD_Applications-32-informational)](gitops/apps)
[![Gates](https://img.shields.io/badge/pytest_gates-49-success)](tests)
[![Clusters](https://img.shields.io/badge/EKS_clusters_provisioned-62-orange)](kcd-texas-provisioning-README.md)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

📊 **[Results](#results)** · 🎤 **[Slides (PDF)](slides/kcd-texas-2026-the-90-minute-idp-as-presented.pdf)** · 🧪 **[The spec](spec/BUILD-SPEC.md)** · 📋 **[Scorecard](scorecard/results/presenter-2026-05-15.md)** · 🗺️ **[What's next](spec/ROADMAP-NEXT-GEN-PHASES.md)**

---

## The question the workshop was built to answer

AI has eaten the implementation layer. The interesting question is not whether it can install ArgoCD, because it obviously can. The question is what is left over once it has, and whether that residue is small enough to ignore or large enough to still be a job.

So the workshop did not argue about it. It built a real platform on real infrastructure in front of a real audience, and scored every component on three separate dimensions instead of one:

| Dimension | The question it asks |
|---|---|
| **Install** | Did the component come up Healthy on the first attempt? |
| **Integration** | Does it actually work *with* the rest of the stack, end to end? |
| **Usability** | Could a developer on your team drive this on Monday morning? |

Collapsing those three into a single "did it work" is what makes AI capability arguments useless. Kept apart, the gap between them is the entire finding.

## Results

Seven phases, 27 CNCF components, built live on Amazon EKS in front of the room.

| Phase | Install | Integration | Usability | AI time |
|---|---:|---:|---:|---:|
| 1. Foundation | 10 | 8 | 9 | 1 min |
| 2. GitOps Bootstrap | 10 | 10 | 9 | 3 min |
| 3. Security Stack | 10 | 8 | 7 | 3 min |
| 4. Observability | 9 | 9 | 9 | 4 min |
| 5. Developer Portal | 10 | 7 | **3** | 8 min |
| 6. Integration | 10 | 10 | 8 | 1 min |
| 7. Hardening | 9 | 5 | 5 | 1 min |
| **Average** | **9.7** | **8.1** | **7.1** | **21 min** |

**Install 9.7, Integration 8.1, Usability 7.1.** The curve is the finding. AI installs almost perfectly, integrates well but not completely, and leaves usability roughly where it found it.

The three lowest scores are the most useful ones in the table:

- **Backstage, Usability 3 of 10.** The pod is Healthy, the catalog is seed-only and the software templates are not wired to a real Git remote. Installed, and not shippable. That distinction is the whole talk.
- **External Secrets Operator, Integration 2 of 10.** The operator runs; the `ClusterSecretStore` reports `InvalidIdentityToken: No OpenIDConnect provider found in your account`. AI installed the component correctly and the AWS prerequisite (IRSA) was never wired, because wiring it was never the component's job.
- **cert-manager, Integration 5 of 10.** ClusterIssuers register and cannot mint a real certificate without DNS-01 wiring that lives outside the cluster.

None of those are AI failures. They are the shape of the work that does not disappear.

### Against an unpressured baseline

The same 7-phase spec had been run overnight, alone, without an audience, in a separate repo ([kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day)).

| | Overnight, alone | Live, 90 minutes, audience | Delta |
|---|---:|---:|---|
| Install average | ~8.3 | **9.7** | +1.4 |
| Integration average | ~8.5 | **8.1** | −0.4 |
| Total wall time | ~10 hours | **~21 min AI time** | ~28× faster |

The live run beat the unpressured run on Install, because by then the spec, the skill files and the test gates had been hardened against a real cluster. Integration held roughly flat, because its limits are environmental rather than procedural. Speed came from the spec, not from luck.

### Room and delivery

Of the ten EKS credentials claimed by attendees, seven clusters showed workshop activity and six reached the full 32-Application fan-out, so 6 of 10 completed fully and 7 of 10 got partway or better. The browser-lab path (roughly 50 more attendees on KodeKloud) is honestly unmeasurable: those labs never touch the credential pool and reset on teardown, so no server-side record survives. That gap is [issue #3](https://github.com/peopleforrester/KCD_Texas_2026_Workshop/issues/3).

> "Almost full house, engaged, felt like something magical was happening even as we talked platform engineering and Claude Code."

**On how these numbers were captured.** The live `/score-component` command did not write to the canonical file during the on-stage build, so this scorecard was reconstructed within about 30 minutes of the closing slide, from a parallel sweep of all 62 provisioned clusters plus the presenter's readout of the room. Cluster counts and Healthy/Degraded states are hard evidence. The 1-to-10 scores are judgement, applied consistently against pre-documented variance points. The capture failure is written up as [issue #2](https://github.com/peopleforrester/KCD_Texas_2026_Workshop/issues/2) rather than quietly smoothed over, and the full record with its provenance section is in [`scorecard/results/presenter-2026-05-15.md`](scorecard/results/presenter-2026-05-15.md).

## What got built

Each phase ends only when its pytest gate exits zero. No gate, no promise, no next phase.

1. **Foundation**. Cluster preflight and the nine workshop namespaces. metrics-server handling branches by cluster type, since EKS ships it as a managed addon while kubeadm needs an upstream install plus the `--kubelet-insecure-tls` patch.
2. **GitOps Bootstrap**. ArgoCD installed by Helm, then one `kubectl apply` of the app-of-apps, after which ArgoCD fans out 32 child Applications in sync-wave order. Full fan-out was discovered in about 48 seconds.
3. **Security Stack**. Kyverno with three ClusterPolicies, Falco with custom CRITICAL-tagged rules, Falcosidekick, FalcoTalon auto-remediation, External Secrets Operator, RBAC and NetworkPolicies.
4. **Observability**. The kube-prometheus-stack, OpenTelemetry Collector, Loki, Promtail, Tempo and ArgoCD ServiceMonitors.
5. **Developer Portal**. Backstage, including the `appConfig` override that stops the Kubernetes plugin crashing on startup on the upstream image.
6. **Integration**. Cross-component verification: ArgoCD drift selfHeal, admission event to metrics, Falco to FalcoTalon end to end.
7. **Hardening**. The cert-manager stack and ClusterIssuers, ResourceQuotas, PodDisruptionBudgets.

Plus ten demo workloads so the platform had something to actually govern.

## The method, which is the transferable part

The platform is a demonstration. The method is the thing worth stealing, and it is four files-worth of idea:

| Artifact | Where | What it does |
|---|---|---|
| **The spec** | [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md) | About 120 lines of plain Markdown. What to build, in what order, pinned to what versions. Pasted once; the model executes all seven phases autonomously. |
| **The skills** | [`.claude/skills/`](.claude/skills/) | One file per CNCF project, documenting what is true about that chart *now*. Auto-loaded before the model generates anything. |
| **The gates** | [`tests/`](tests/) | 49 pytest assertions across seven phase files. Real `kubectl` calls, no mocks. A phase is done when its gate is green, not when the output looks right. |
| **The scorecard** | [`scorecard/`](scorecard/) | Three dimensions per phase, captured by a slash command rather than typed into Markdown by hand. |

The skill files exist because of a specific and repeatable failure. Ask a model to install a Helm chart and it will confidently reproduce a pattern from two chart generations ago, because that pattern dominates the tutorials it learned from. Every skill file here encodes a trap that was hit for real. Two examples that cost hours:

- The Backstage image most tutorials name (`roadiehq/community-backstage-image:1.50.4`) **does not exist anywhere**. It 404s on GHCR and the Docker Hub lineage was abandoned in 2021. The working pin is `ghcr.io/backstage/backstage:1.30.2`.
- That upstream image ships an app-config that initialises the Kubernetes plugin, which then crashes at startup unless a cluster locator is supplied. The fix is a `backstage.appConfig` override, and nothing tells you this until the pod is in CrashLoopBackOff.

Spec, skills and gates together are what turned a ten-hour overnight build into twenty-one minutes of AI time in front of an audience.

## The infrastructure behind it

62 EKS clusters, provisioned by Terraform, handed out by a Flask app during the session.

- 3× t3.xlarge nodes per cluster on EKS 1.34, roughly $0.65 per cluster-hour, about $125 for the whole event
- Cluster auth via EKS Access Entries rather than the `aws-auth` ConfigMap
- One temporary IAM user per attendee, each behind a permissions boundary that allowlists only EKS and its supporting services
- A second delivery path on KodeKloud kubeadm clusters, so browser-only attendees needed no local installs at all, with the spec branching on a `.cluster-type` marker file at three points

Terraform, batch provisioning and teardown, and the IAM lifecycle scripts are all in [`kcd-texas-provisioning/`](kcd-texas-provisioning/) and [`scripts/`](scripts/).

## Repo map

| Path | What's in it |
|---|---|
| [`spec/`](spec/) | The build spec, the presenter runbook, the opening script, per-phase scripts with known failure modes |
| [`.claude/`](.claude/) | Skill files, slash commands, settings. Auto-loads when Claude Code starts from this root |
| [`gitops/`](gitops/) | The canonical Kubernetes state: app-of-apps, 32 Applications, policy manifests |
| [`tests/`](tests/) | 49 pytest gates across seven phase files, real cluster calls |
| [`scorecard/`](scorecard/) | Template, presenter scorecard, and [the results](scorecard/results/) including two dress rehearsals |
| [`slides/`](slides/) | The deck as presented, in PDF |
| [`demo/`](demo/) | 20 terminal scripts, one per component, for verifying any single piece live |
| [`assets/`](assets/) | Mermaid sources and rendered architecture diagrams |
| [`INSTRUCTOR.md`](INSTRUCTOR.md) | Run sheet for anyone presenting this themselves |
| [`kcd-tx-attendee-playbook.md`](kcd-tx-attendee-playbook.md) | The attendee-facing guide used on the day |

## Run it yourself

MIT licensed. Fork it, run it, change it.

```bash
git clone https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git
cd KCD_Texas_2026_Workshop
bash scripts/dry-run-validate.sh .    # static checks, no cluster needed
claude                                # skills and commands auto-load from this root
```

Then paste [`spec/BUILD-SPEC.md`](spec/BUILD-SPEC.md) against any cluster you control. Budget around three hours to land all 27 components without time pressure. [`INSTRUCTOR.md`](INSTRUCTOR.md) covers presenting it to a room.

## What's next

The seven-phase build is finished and frozen as delivered. Phases 8 through 16 extend it into an AI-native, identity-first platform: an agent gateway, SPIFFE workload identity, Dex human identity with JIT access, an OpenBao secrets vault, a supply-chain hardening pass and a service mesh.

Written up in [`spec/ROADMAP-NEXT-GEN-PHASES.md`](spec/ROADMAP-NEXT-GEN-PHASES.md) and broken into pickup-ready [GitHub issues](https://github.com/peopleforrester/KCD_Texas_2026_Workshop/issues), indexed by [the epic](https://github.com/peopleforrester/KCD_Texas_2026_Workshop/issues/14). The recommended order ships one phase per iteration, because bundling them dilutes what each one teaches.

## Related

- **[agentic-covenants](https://github.com/peopleforrester/agentic-covenants)** is the prevention-first governance framework this workshop is a worked example of. The Kyverno policies here are the Authorization and Blast-radius rows of that matrix, enforced server-side.
- **[kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day)** is the same spec run overnight without time pressure, and the baseline the results above are measured against.

## Author

**Michael Forrester**. Platform engineering, developer education, and the awkward questions about what AI actually leaves behind.

Questions and replication notes are welcome as issues on this repository.

## License

[MIT](LICENSE)
