# Build Spec — "The 90-Minute IDP" (Full 27-component build)

This is the spec I (Michael) hand Claude Code on stage at KCD Texas. **Single paste, autonomous execution, deliberate pauses for scoring.**

The build follows the same 7-phase / 27-component shape as the [kubeauto-ai-day reference build](https://github.com/peopleforrester/kubeauto-ai-day) — same battle-tested methodology, executed against a pre-provisioned cluster instead of a from-zero terraform-apply.

**No artificial scope ceiling.** The workshop is 90 minutes; Claude executes the spec autonomously and gets as far as it gets. If we land Phase 4 in 90 min, that's data. If we land Phase 7, even better. Whatever doesn't finish in the room, the audience finishes on the plane home using this same spec.

## Two cluster environments

The workshop runs against **two environments** in the same room at the same time:

- **Path A — Accenture EKS** (10 clusters, primary for terminal-comfortable attendees). Cluster creds distributed via https://bubbly-harmony-production-574d.up.railway.app/. EKS 1.32, AWS Pod Identity available.
- **Path B — KodeKloud browser lab** (per-attendee, primary for browser-preferring attendees and the majority by headcount). Vanilla kubeadm v1.36, Calico/Canal CNI, no AWS, no IRSA. Course at https://learn.kodekloud.com/user/courses/the-90-minutes-idp.

Claude **MUST** detect cluster type at the start of Phase 1 by inspecting `kubectl config current-context`:

- `kubernetes-admin@kubernetes` → `CLUSTER_TYPE=kubeadm`
- ARN or anything containing `eks` → `CLUSTER_TYPE=eks`

Write the result to `.cluster-type` at the repo root (one word: `eks` or `kubeadm`). Every subsequent phase reads this marker to branch behavior where it matters:

| Phase | Branches on cluster type? |
|---|---|
| 1 (Foundation) | **Yes** — EKS pre-installs `metrics-server` as a managed addon (verify only, do not re-apply); kubeadm requires a fresh install plus the `--kubelet-insecure-tls` patch |
| 2 (GitOps Bootstrap) | No — identical on both |
| 3 (Security Stack) | **Yes** — ESO backend (AWS Secrets Manager on EKS / Kubernetes Secrets on kubeadm) |
| 4 (Observability) | No — identical on both |
| 5 (Developer Portal) | No — identical on both |
| 6 (Integration) | No — identical on both |
| 7 (Hardening) | **Yes** — cert-manager ClusterIssuer (ACME/Route53 on EKS / self-signed on kubeadm) |

The scorecard rows will diverge between the two paths on Phase 3 (ESO) and Phase 7 (cert-manager) **by design** — that's the talk's central A/B running live in the same room. **Don't try to make KodeKloud look like EKS, or vice versa.** Either path is a valid workshop run; the divergence is the data.

Full per-component branching guide: `.claude/skills/cluster-environments.md`.

## How Claude executes this spec

Open Claude Code in the cloned workshop repo. Paste this entire prompt — that's the only one I paste all workshop:

```
Read spec/BUILD-SPEC.md and execute it autonomously.

The build is 7 phases (1 → 7). Phase 1 asserts the pre-provisioned cluster
foundation. Phase 2 bootstraps ArgoCD + the app-of-apps that fans out to ALL
21 platform Applications. ArgoCD then reconciles them in sync-wave order in
parallel. Phases 3 → 7 are score-and-narrate phases: wait for the relevant
components to reach Healthy, run the pytest gate, score, promise, continue.

Per phase, in order:
  1. Read spec/phases/phase-0N-*.md (the phase reference)
  2. Read the skill file the phase points to in .claude/skills/ (if any)
  3. For Phase 1 & 2: generate the manifest the phase asks for, saved to
     ~/my-<component>.yaml. Diff against the pre-committed ground truth in
     gitops/. Walk me through the diff out loud.
  4. For Phase 3 → 7: the components are already reconciling from Phase 2's
     app-of-apps. Wait for the phase's components to reach Healthy
     (Application + underlying Pods). Surface failures honestly.
  5. Run the pytest test gate: pytest tests/test_phase_0N_*.py -v
  6. ALL tests must pass. Not most. Not "good enough." All.
  7. When all tests pass, output: <promise>PHASE_N_DONE</promise>
     Then PAUSE. Wait for me to score and say "continue".
  8. If any test fails: narrate the failure using the phase spec's "Known
     failure modes" section. Attempt ONE diagnostic fix. If the gate still
     fails, output <promise>PHASE_N_FAILED</promise> with notes — do not
     fake a pass. The failure is part of the talk.

When all 7 phases complete (or I say "stop"), output:
<promise>ALL_PHASES_COMPLETE</promise>

Always read the skill file BEFORE generating config. Never skip the diff
step. Never fake a promise. The audience is watching the projector.
```

That's it. Single paste. Claude executes autonomously, pausing only for me to score after each promise.

## The seven phases

| Phase | Theme | Components | Phase reference | Test gate |
|---|---|---|---|---|
| 1 | Foundation (assert pre-provisioned) | Cluster, nodes, namespaces, addons | `spec/phases/phase-01-foundation.md` | `tests/test_phase_01_foundation.py` |
| 2 | GitOps Bootstrap | ArgoCD, app-of-apps, sync waves | `spec/phases/phase-02-gitops.md` | `tests/test_phase_02_gitops.py` |
| 3 | Security Stack | Kyverno + 3 policies, Falco + rules, Falcosidekick, **FalcoTalon (auto-response)**, ESO + Secrets, RBAC, NetworkPolicies | `spec/phases/phase-03-security.md` | `tests/test_phase_03_security.py` |
| 4 | Observability | kube-prometheus-stack, Grafana dashboards, ArgoCD ServiceMonitors, OTel Collector, Loki, Promtail, Tempo, Alert rules | `spec/phases/phase-04-observability.md` | `tests/test_phase_04_observability.py` |
| 5 | Developer Portal | Backstage, software templates, plugin wiring, backstage-resources | `spec/phases/phase-05-portal.md` | `tests/test_phase_05_portal.py` |
| 6 | Integration | End-to-end: drift→sync, policy fires while metrics scrape, audit trail across components | `spec/phases/phase-06-integration.md` | `tests/test_phase_06_integration.py` |
| 7 | Hardening | cert-manager + ClusterIssuers, ResourceQuotas + PDBs, OIDC auth, documentation/ADRs | `spec/phases/phase-07-hardening.md` | `tests/test_phase_07_hardening.py` |

## How the 27 components are deployed

Phase 2 applies `gitops/bootstrap/app-of-apps.yaml` which references `gitops/apps/` containing **21 ArgoCD Applications**. ArgoCD reconciles them in this sync-wave order:

| Wave | Application(s) | Phase |
|---|---|---|
| -10 | namespaces | 1 |
| -5  | kyverno | 3 |
| -4  | kyverno-policies, external-secrets, rbac, network-policies | 3 |
| -3  | falco, eso-resources | 3 |
| -2  | falcosidekick | 3 |
| 1   | cert-manager, kube-prometheus-stack | 4, 7 |
| 2   | argocd-servicemonitors, otel-collector | 4 |
| 3   | grafana-dashboards, loki, tempo, resource-quotas, cert-manager-issuers | 4, 7 |
| 4   | promtail, **falco-talon** | 4, 3 |
| 5   | backstage, backstage-resources | 5 |

> **Note:** sync waves track Kubernetes dependency ordering, not the workshop's phase narrative. cert-manager (Phase 7) is in Wave 1 because its CRDs must exist before cert-manager-issuers can apply; the issuers themselves are deferred to Wave 3 (rather than Wave 2) to give the cert-manager-webhook Service one extra wave of slack to populate endpoints — without it the first sync attempt routinely hits `no endpoints available for service "cert-manager-webhook"`. resource-quotas (Phase 7) is in Wave 3 so it's enforcing admission limits before workloads (Wave 5+) get created. The two numbering schemes are orthogonal by design — waves are deployment plumbing, phases are scorecard narrative.

Each Application points at either an upstream Helm chart (Kyverno, Falco, cert-manager, Prometheus, OTel, etc.) or at a manifest path in this repo or in `github.com/peopleforrester/kubeauto-ai-day` (the source of truth for shared pre-built config).

The 6 components that aren't ArgoCD Applications are scored differently:
- **4 Foundation components** (VPC, EKS, IAM, Pod Identity) — pre-provisioned by Accenture; scored as "infra existed Healthy" in Phase 1
- **2 Pattern components** (App-of-Apps pattern, Sync Wave Ordering) — scored as "the pattern worked" in Phase 2

That brings us to 21 + 4 + 2 = **27 components** matching kubeauto-ai-day's SCORECARD.

## Promise discipline (strict)

```
<promise>PHASE_N_DONE</promise>      ← only when every pytest gate passes
<promise>PHASE_N_FAILED</promise>    ← real failure after one diagnostic round; honest
<promise>ALL_PHASES_COMPLETE</promise>  ← at end of Phase 7 or when I say stop
```

Faked passes undermine the workshop's central claim and will be visible to anyone watching the pytest output on the projector.

## The three scoring dimensions (applied per-component, not per-phase)

| Dimension | What it measures | A 10 looks like |
|---|---|---|
| **Install** | Did the component come up Healthy on the first try? | Pods Running, manifest correct first try, no rewrites |
| **Integration** | Does it work *with* the other components? | Sync waves right, webhooks scoped, scrape working, secrets pulled, etc. |
| **Usability** | Could a developer drive this Monday morning? | Clear UI, sensible defaults, the right things discoverable |

Plus **correction cycles** (follow-up prompts) and **AI wall-clock time** (paste-of-spec to component-Healthy).

The variance between Install (usually high) and Usability (usually low) across phases is the talk's anchor.

## Stack pins (committed in `gitops/`, render-validated upstream)

| Component | Helm chart | Version | Notes |
|---|---|---|---|
| ArgoCD | `argo/argo-cd` | 9.x line (current stable GA) | ArgoCD v3.4.x app version |
| Kyverno | `kyverno/kyverno` | `3.8.0` | Kyverno v1.18.0 |
| kube-prometheus-stack | `prometheus-community/kube-prometheus-stack` | `84.5.0` | Prometheus operator v0.90.x |
| Backstage | `backstage/backstage` | `2.7.0` | `ghcr.io/backstage/backstage:1.30.2` + appConfig override |
| Falco | `falcosecurity/falco` | `8.0.5` | modern_ebpf driver (app v0.43.1) |
| Falcosidekick | `falcosecurity/falcosidekick` | `0.13.1` | Forwards to Prometheus + Talon (wired); Slack/Teams optional |
| **FalcoTalon** | `falcosecurity/falco-talon` | `0.4.0` | Auto-response engine; default action `kubernetes:terminate` on shell-spawn |
| cert-manager | `jetstack/cert-manager` | `v1.19.3` | CRDs managed by chart |
| External Secrets | `external-secrets/external-secrets` | `1.3.2` | IRSA role required for actual secret pulls |
| OTel Collector | `open-telemetry/opentelemetry-collector` | (chart default in `otel-collector.yaml`) | DaemonSet mode |
| Loki / Tempo / Promtail | `grafana/*` | (chart defaults pinned in each Application) | Log aggregation + tracing |

Skill files have the exact `valuesObject` blocks and lead with the trap Claude tends to fall into without them.

## Caveats specific to the Accenture workshop cluster context

These don't break the build but produce honest scorecard variance:

- **ESO + AWS Secrets Manager.** Workshop cluster doesn't have the IRSA role provisioned. ESO will deploy and reach Healthy, but its `ClusterSecretStore` will fail to authenticate. Integration scores low. To wire up, set a real IRSA role ARN in `gitops/apps/external-secrets.yaml`.
- **cert-manager + ClusterIssuers.** Workshop uses port-forward, not real TLS. ClusterIssuers will sync but `Order` resources won't complete without real DNS-01 or HTTP-01 wiring.
- **OIDC Authentication.** Requires a real GitHub OAuth app. Skipped unless that's pre-provisioned for the cluster.

This is exactly the kind of honest "AI did the install, but ops still need to wire prerequisites" variance the workshop is built to expose.

## Repository discipline

- **All edits on `staging` branch.** See `spec/BRANCH-WORKFLOW.md`.
- **Pre-commit hooks** run locally on every commit: gitleaks, yamllint, kubeconform schema validation, helm lint, shellcheck.
- **Pre-push hook** runs `scripts/dry-run-validate.sh` locally before the push lands on staging.
- **Promotion staging → main** is a local fast-forward merge. ArgoCD reads `main`.
- **Manifests are applied via ArgoCD after Phase 2 bootstrap.** No `kubectl apply` to production namespaces post-bootstrap. ArgoCD is the deployer.

## Slash commands (fallback / catch-up use)

- **`/build-phase N`** — re-run just one phase, useful if a student falls behind
- **`/score-component <name>`** — opens the scorecard, walks Install/Integration/Usability
- **`/validate-phase N`** — runs the pytest gate for that phase only

I don't use them on stage in the default flow. They're audience escape valves.

## What everyone takes home

The cluster gets destroyed an hour after the workshop ends. The repo is public.

What goes home:

1. **The filled scorecard.** Honest numbers across however many phases we landed live.
2. **The methodology.** Spec + skills + pytest gates + three-dimension scorecard. Apply it to anything you build with AI on Monday.
3. **The full 27-component spec.** This file. Battle-tested. Run it yourself on a fresh EKS cluster overnight and you'll land all 27 in ~3 hours. We're trying to do it in 90 minutes live.
4. **A reference build.** [`github.com/peopleforrester/kubeauto-ai-day`](https://github.com/peopleforrester/kubeauto-ai-day) — same methodology, same 27 components, ~10 hours overnight (the original AI-assisted run). The variance between today's "live under pressure" scorecard and that "alone overnight" scorecard is the closing slide.
