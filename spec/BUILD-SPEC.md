# Build Spec — "The 90-Minute IDP"

This is the spec I (Michael) hand Claude Code on stage at KCD Texas. Students follow along on their own pre-provisioned EKS clusters, running the same prompts against their own Claude.

The goal is not to finish the IDP. The goal is to demonstrate **spec-driven development with Claude Code** on a real platform-engineering build, score what AI does on three dimensions, and leave the room with a methodology you can use Monday morning.

How far we get is how far we get.

## How this works on stage

I run `claude` from the cloned workshop repo. Claude Code auto-loads everything under `.claude/skills/` and `.claude/commands/`. I hand Claude this spec by saying:

```
Read spec/BUILD-SPEC.md and start with /build-phase 1.
```

Claude reads the spec, reads the Phase 1 file in `spec/phases/`, reads the relevant skill in `.claude/skills/`, and generates the manifest the phase asks for. We apply it. We run the test gate. If it passes, we score on the live scorecard (Install, Integration, Usability) and move to the next phase. If it fails, we narrate the failure — that's part of the show.

**Students follow along.** Same prompts, their own cluster, their own Claude. They score on the connection-card scorecard. If they fall behind during a phase, the test gate at the end of the phase is the catch-up window.

There is no git push. The repo is shared; students don't have write access. Manifests Claude generates live on the student's laptop. Their cluster's ArgoCD reconciles against the pre-committed `gitops/` tree on `main`.

## The four phases

We do them in order. We do as many as fit.

| Phase | Component | What I have Claude generate | Sync wave (matches `gitops/apps/`) | Skill |
|---|---|---|---|---|
| 1 | **ArgoCD + app-of-apps** | `~/my-app-of-apps.yaml` | — (ArgoCD is installed via Helm before app-of-apps) | `argocd-patterns.md` |
| 2 | **Kyverno + 1 policy** | `~/my-kyverno.yaml`, `~/my-require-labels.yaml` | -5, -4 | `kyverno-policies.md` |
| 3 | **kube-prometheus-stack** | `~/my-kube-prometheus-stack.yaml` | 1 | `kube-prometheus-stack.md` |
| 4 | **Backstage** | `~/my-backstage.yaml` | 5 | `backstage-templates.md` |

Phase 4 is most likely to faceplant. If it does, that's the talk title — "AI Ate My Implementation." If we run out of time before Phase 4, I play the pre-recorded run during the closing 5 minutes.

## The three scoring dimensions

For each component, scored independently:

| Dimension | What it measures | A 10 looks like |
|---|---|---|
| **Install** | Did Claude generate a manifest that brought the component up healthy? | Pods Running, no rewrites, manifest correct first try, structurally matches the pre-committed reference |
| **Integration** | Does it work *with* the other components? | Sync waves right, ArgoCD discovers it, webhooks scoped correctly, scrape working, no policy collisions |
| **Usability** | Could a developer drive this Monday morning? | Clear UI, sensible defaults, the right things are discoverable |

Plus **correction cycles** (count of follow-up prompts I had to send) and **AI wall-clock time** (minutes from paste to gate-passes).

The presenter scorecard is the on-stage artifact — six rows × three dimensions. The student scorecard mirrors it. Both fill in real time. The variance between Install and Usability across phases is what the talk is anchored on.

## Stack pins (committed in `gitops/`, render-validated against upstream)

| Component | Helm chart | Version | App version |
|---|---|---|---|
| ArgoCD | `argo/argo-cd` | current stable GA (9.x chart line) | ArgoCD v3.4.x |
| Kyverno | `kyverno/kyverno` | `3.8.0` | Kyverno v1.18.0 |
| kube-prometheus-stack | `prometheus-community/kube-prometheus-stack` | `84.5.0` | Prometheus operator v0.90.x |
| Backstage | `backstage/backstage` | `2.7.0` | `ghcr.io/backstage/backstage:1.30.2` (with `backstage.appConfig` override -- the upstream image's Kubernetes plugin crashes on init without it; see skill + phase spec) |

Skill files have the exact `valuesObject` blocks Claude should generate. Each skill leads with a trap Claude tends to fall into without it (chart 9.x vs 7.x for ArgoCD, the no-default-image trap for Backstage, the ServerSideApply requirement for kube-prometheus-stack).

## Gate-pass = phase done

When a phase's test gate passes (all `kubectl` verify commands return what the phase spec says they should), Claude outputs:

```
<promise>PHASE_N_DONE</promise>
```

That's the signal to score on the live scorecard and move to the next phase. **Don't fake the promise.** Failed gates are part of the talk — narrate honestly.

## Slash commands

Auto-loaded from `.claude/commands/` when I run `claude` from the repo root:

- `/build-phase N` — Claude reads the phase spec + skill, generates the manifest to `~/my-<component>.yaml`, walks through the diff against `gitops/apps/<component>.yaml`, and tells me the gate commands
- `/score-component <name>` — opens the scorecard, walks through the three dimensions
- `/validate-phase N` — runs the gate commands, reports pass/fail, diagnoses against known risks

Students can run the same slash commands on their own Claude if they fall behind or want to drive their own pace.

## What everyone takes home

The platform gets destroyed an hour after the workshop ends. The manifests are in the public repo.

What goes home:

1. **The filled scorecard.** Honest numbers across however many phases we landed.
2. **The methodology.** Spec + skills + test gates + scorecard with three dimensions. Applies to whatever you build with AI on Monday.
3. **A reference build to compare against.** [`github.com/peopleforrester/kubeauto-ai-day`](https://github.com/peopleforrester/kubeauto-ai-day) — 7 phases, 27 components, ~10 hours, full scorecard. The variance between today's "live under pressure" scores and that "alone overnight" scorecard is the data the closing slide hangs on.
