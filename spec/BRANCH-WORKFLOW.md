# Branch Workflow

The workshop repo uses a **staging-first, promote-to-main** branch model. Validation is **local-only** — pre-commit hooks and the dry-run validator run on Michael's machine. No GitHub Actions, no CI runs, no remote gates. Students don't interact with CI at all; they clone and run locally.

This is single-maintainer discipline, not multi-developer collaboration tooling.

## The two branches

- **`staging`** — working branch. All edits land here first. Pre-commit hooks run locally on commit. The dry-run validator runs locally on pre-push. Nothing on staging is "shipped" until it's been validated.
- **`main`** — canonical. ArgoCD reads from `main` (verify: `grep targetRevision gitops/bootstrap/app-of-apps.yaml` → should say `main`). Only promoted commits from staging land here.

## What lives where

| Artifact | Editable on | Read by |
|---|---|---|
| `gitops/apps/*.yaml` | staging | ArgoCD (from main) |
| `gitops/manifests/**/*.yaml` | staging | ArgoCD (from main) |
| `gitops/bootstrap/app-of-apps.yaml` | staging | Workshop attendees apply this from main during Phase 1 |
| `spec/**/*.md` | staging | Claude Code (presenter + students from main) |
| `.claude/skills/*.md` | staging | Claude Code (from main) |
| `.claude/commands/*.md` | staging | Claude Code (from main) |
| `tests/test_phase_*.py` | staging | Maintainer in rehearsal (run locally via pytest) |
| `scripts/dry-run-validate.sh` | staging | Maintainer (run locally) |
| `kcd-texas-student-playbook.md` | staging | Attendees during the workshop (from main) |

## The local workflow

```bash
# Always start on staging
git checkout staging
git pull origin staging

# Edit (skill, spec, gitops manifest, test, whatever)
$EDITOR spec/BUILD-SPEC.md

# Pre-commit hooks run automatically on commit
git add spec/BUILD-SPEC.md
git commit -m "workshop: tighten phase-1 spec language"
# Pre-commit: gitleaks, yamllint, kubeconform, helm-lint, shellcheck
# Failure → re-fix; don't bypass with --no-verify

# Push to staging (pre-push hook runs the dry-run validator locally)
git push origin staging
# Pre-push: bash scripts/dry-run-validate.sh . must pass 56/56
```

When staging is green and you want to promote to main:

```bash
# Switch to main, fast-forward to staging, push
git checkout main
git merge --ff-only staging
git push origin main
```

Fast-forward only — if staging and main have diverged, that's a signal to figure out why before pushing. No surprise merges to main.

ArgoCD picks up the new main commit on its next reconcile (30s in the workshop).

## What "the dry-run validator" does

`scripts/dry-run-validate.sh` runs locally — no cluster needed — and checks:

1. Required tools available (helm, kubectl, python3, git)
2. Repo structure (all expected directories present)
3. Every required file present (specs, skills, commands, tests, gitops manifests, scorecard)
4. All YAML parses cleanly
5. Helm repos can be added and updated
6. The chart versions pinned in `gitops/apps/` exist upstream
7. Each Application's `helm.valuesObject` renders cleanly via `helm template` against the real upstream chart
8. Sync waves match between specs and `gitops/apps/` (drift check)
9. ArgoCD chart 9.x is current GA upstream
10. Pytest tests collect cleanly (syntactic + import check)

If all checks pass, the repo is in a state where workshop-day execution should not surface surprises about chart versions, render-validity, sync-wave drift, or file presence.

## Why no GitHub Actions

- **Students don't interact with CI.** They clone the repo and run locally. A CI workflow file would just sit there, irrelevant.
- **Single maintainer.** Michael is the only person committing. The "second pair of eyes" CI provides on a team is unnecessary here.
- **Pre-commit + pre-push is sufficient.** Every check that CI would run is also a pre-commit or pre-push hook. The local gate IS the gate.
- **Workshop-day reality.** What matters is that `gitops/` is render-valid, the specs are coherent, and pytest tests collect. All three are validated on every push to staging via the local hooks.

## What this is NOT

- Not a multi-developer GitFlow. There's one maintainer.
- Not enforced by remote tooling. The hooks are local; bypass with `--no-verify` is technically possible (don't).
- Not a TDD-first development workflow in the strict sense. The pytest tests are **verification** gates run during rehearsal and on stage against a real cluster, not red-green-refactor cycles.

## The kubeauto-ai-day parallel

| Kubeauto rule | Workshop equivalent |
|---|---|
| All commits on `staging` branch only | Same — verify with `git branch --show-current` before committing |
| Pre-push: `uv run pytest tests/ -v` | Pre-push: `bash scripts/dry-run-validate.sh .` (pytest runs during manual rehearsal against a real cluster, not on every push) |
| Output `<promise>PHASEX_DONE</promise>` only when all tests pass | Same — strict promise discipline in `spec/BUILD-SPEC.md` |
| Skills auto-loaded from `.claude/skills/` | Same |
| Each commit must pass full test suite | Adapted — each push to staging passes the dry-run; pytest passes in rehearsal |
| No mocked clients | Same — `tests/conftest.py` shells out to real `kubectl` against the real EKS cluster |

The difference: kubeauto's setup was a longer-running project where remote CI made sense. The workshop is a single-event package shipped to a public repo for a single 90-minute audience. Local validation is the appropriate scope.
