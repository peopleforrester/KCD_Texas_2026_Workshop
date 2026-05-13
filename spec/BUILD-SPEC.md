# Build Spec — "The 90-Minute IDP"

This is the spec I (Michael) hand Claude Code on stage at KCD Texas. **Single paste, autonomous execution, deliberate pauses for scoring.**

Same pattern as `kubeauto-ai-day/spec/BUILD-SPEC.md`: Claude reads this spec, reads each phase's reference doc, reads the relevant skill, executes, runs the pytest test gate, emits a promise *only when all tests pass*, and waits for me to score before continuing. Same rigor, compressed to 90 minutes.

## How Claude executes this spec

Open Claude Code in the cloned workshop repo. Paste this entire prompt — that's the only one I paste all workshop:

```
Read spec/BUILD-SPEC.md and execute it autonomously.

Workflow per phase, in order (Phase 1 → 4):
  1. Read spec/phases/phase-0N-*.md (the phase reference)
  2. Read the skill file the phase points to in .claude/skills/
  3. Generate the manifest the phase asks for, saved to ~/my-<component>.yaml
  4. Diff ~/my-<component>.yaml against the pre-committed ground truth in
     gitops/apps/<component>.yaml (or wherever the phase spec says)
  5. Walk me through the diff out loud
  6. Run the pytest test gate: pytest tests/test_phase_0N_*.py -v
  7. ALL tests must pass. Not most. Not "good enough." All.
  8. When all tests pass, output: <promise>PHASE_N_DONE</promise>
     Then PAUSE. Wait for me to score and say "continue".
  9. If any test fails, narrate the failure honestly using the phase spec's
     "Known failure modes" section. Attempt ONE diagnostic fix. If the gate
     still fails, output <promise>PHASE_N_FAILED</promise> with notes — do
     not fake a pass. The failure is part of the talk.

After all four phases (or after I say "stop"), output:
<promise>ALL_PHASES_COMPLETE</promise>

Always read the skill file BEFORE generating config. Never skip the diff step.
Never fake a promise. The audience is watching the projector.
```

That's it. Single paste. Claude executes autonomously, pausing only for me to score after each promise.

## The four phases (executed in order)

| Phase | Component | Phase reference | Skill | Test gate |
|---|---|---|---|---|
| 1 | ArgoCD + app-of-apps | `spec/phases/phase-01-argocd.md` | `argocd-patterns.md` | `tests/test_phase_01_argocd.py` |
| 2 | Kyverno + 1 ClusterPolicy | `spec/phases/phase-02-kyverno.md` | `kyverno-policies.md` | `tests/test_phase_02_kyverno.py` |
| 3 | kube-prometheus-stack | `spec/phases/phase-03-observability.md` | `kube-prometheus-stack.md` | `tests/test_phase_03_observability.py` |
| 4 | Backstage | `spec/phases/phase-04-backstage.md` | `backstage-templates.md` | `tests/test_phase_04_backstage.py` |

How far we get is how far we get. Phase 4 is most likely to faceplant; if it does, that's the talk.

## Promise discipline (strict)

```
<promise>PHASE_N_DONE</promise>
```

Emitted **only when every pytest in the phase's test gate passes**. Not when "the chart installed but one assertion is a little off." Not "let me waive the integration check." All tests. Pass. Period.

```
<promise>PHASE_N_FAILED</promise>
```

Emitted when a real failure happens that one diagnostic round didn't fix. The failure is captured in the scorecard and we move on. Faked passes undermine the workshop's central claim and will be visible to anyone watching the pytest output on the projector.

```
<promise>ALL_PHASES_COMPLETE</promise>
```

Emitted at the end of Phase 4 (or when I say "stop"), regardless of how many phases passed vs failed.

## The three scoring dimensions

For each component, scored independently after the phase promise:

| Dimension | What it measures | A 10 looks like |
|---|---|---|
| **Install** | Did Claude generate a manifest that, after applying, brought the component up healthy on the first try? | Pods Running, no rewrites, manifest correct first try, diff against ground truth shows only stylistic differences |
| **Integration** | Does it work *with* the other components? | Sync waves right, ArgoCD discovers/syncs/heals, webhooks scoped correctly, scrape working, no cross-component breakage |
| **Usability** | Could a developer drive this Monday morning? | Clear UI, sensible defaults, the right things are discoverable, dashboards/catalog/policies actually usable |

Plus **correction cycles** (how many follow-up prompts I sent Claude) and **AI wall-clock time** (paste-of-spec to phase-promise).

The variance between Install (usually high) and Usability (usually low) across phases is the talk's anchor.

## Stack pins (committed in `gitops/`, render-validated upstream)

| Component | Helm chart | Version | App version |
|---|---|---|---|
| ArgoCD | `argo/argo-cd` | current stable GA (chart 9.x line) | ArgoCD v3.4.x |
| Kyverno | `kyverno/kyverno` | `3.8.0` | Kyverno v1.18.0 |
| kube-prometheus-stack | `prometheus-community/kube-prometheus-stack` | `84.5.0` | Prometheus operator v0.90.x |
| Backstage | `backstage/backstage` | `2.7.0` | `ghcr.io/backstage/backstage:1.30.2` (with `backstage.appConfig` override -- the upstream image's Kubernetes plugin crashes on init without it; see Phase 4 + skill.  `roadiehq/community-backstage-image:1.50.4` -- referenced in earlier tarballs -- does not exist) |

Skill files have the exact `valuesObject` blocks. Each skill file leads with the trap Claude tends to fall into without it.

## Repository discipline (matches kubeauto's local rigor)

- **All edits on `staging` branch.** See `spec/BRANCH-WORKFLOW.md`.
- **Pre-commit hooks** run locally on every commit: gitleaks, yamllint, kubeconform schema validation, helm lint, shellcheck.
- **Pre-push hook** runs `scripts/dry-run-validate.sh` locally — must pass 55/55 before the push lands on staging.
- **Promotion staging → main** is a local fast-forward merge (`git merge --ff-only staging` from main, then push). No remote gates; the local pre-push validator is the gate.
- **ArgoCD reads `main`.** Anything on staging is in-flight; nothing reaches a cluster until it's on main.
- **Manifests must be applied via ArgoCD after Phase 1.** No `kubectl apply` to production namespaces post-bootstrap. ArgoCD is the deployer.

## Slash commands (fallback / catch-up use)

The primary mode is single-paste autonomous execution. The slash commands exist for:

- **`/build-phase N`** — students who fell behind during a phase can catch up by re-running just that phase
- **`/score-component <name>`** — opens the scorecard, walks through Install/Integration/Usability
- **`/validate-phase N`** — runs the pytest gate for that phase only

I don't use them on stage in the default flow. They're audience escape valves.

## What everyone takes home

The platform gets destroyed an hour after the workshop ends. The repo is public.

What goes home:

1. **The filled scorecard.** Honest numbers across however many phases we landed.
2. **The methodology.** Spec + skills + pytest gates + three-dimension scorecard. Apply to whatever you build with AI on Monday.
3. **A reference build.** [`github.com/peopleforrester/kubeauto-ai-day`](https://github.com/peopleforrester/kubeauto-ai-day) — same methodology, 7 phases, 27 components, ~10 hours overnight. The variance between today's "live under pressure" scorecard and that "alone overnight" scorecard is the data the closing slide hangs on.
