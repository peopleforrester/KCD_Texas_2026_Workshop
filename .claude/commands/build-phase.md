# /build-phase $ARGUMENTS

**This is a catch-up / fallback command.** The primary workflow is single-paste autonomous execution from `spec/BUILD-SPEC.md` (see the prompt block under "How Claude executes this spec"). This slash command runs just one phase end-to-end — useful when:

- A student fell behind during the live workshop and wants to catch up on a specific phase
- The autonomous loop got stuck and Michael wants to force re-execution of a single phase
- Someone running through the workshop materials post-hoc wants to step through one phase at a time

## Your job in this command

1. **Read** `spec/BUILD-SPEC.md` for the workshop framing (autonomous-execution model, three-dimension scoring)
2. **Read** `spec/phases/phase-0$ARGUMENTS-*.md` for this phase's goal, prompt, test gate file, known failure modes
3. **Read** the skill file referenced by the phase spec — before generating anything
4. **Walk through the architecture** when the phase spec asks you to (the "first, explain..." step)
5. **Generate** the manifest(s) the phase asks for, saved to `~/my-<component>.yaml`
6. **Diff** the generated manifest against the pre-committed ground truth. Walk through every difference.
7. **Run the pytest test gate:** `pytest tests/test_phase_0$ARGUMENTS_*.py -v`
8. **Every test must pass.** If any fail, narrate using the phase spec's Known failure modes, attempt ONE diagnostic fix, then either re-run and pass or emit `<promise>PHASE_${ARGUMENTS}_FAILED</promise>`.

## Completion

When `pytest tests/test_phase_0$ARGUMENTS_*.py -v` exits 0 (all tests pass):

```
<promise>PHASE_${ARGUMENTS}_DONE</promise>
```

**Do not fake the promise.** A faked promise is visible to anyone reading the pytest output on the projector — and it undermines the workshop's central claim.

## Rules

- **Read the skill file first.** Every skill encodes a trap Claude tends to fall into. Skipping the skill produces deprecated patterns.
- **Generate to `~/my-<component>.yaml`** — not into `gitops/`. The repo is read-only during the workshop.
- **Diff is the educational moment.** Don't skim past it.
- **Narrate failures by name** — match to the phase spec's Known failure modes.
- **Do not suggest scores.** Scoring is the user's job (presenter or student); your role is honest comparison and clean test execution.

## What this command does NOT do

- It does not `git push`. Students don't push.
- It does not modify files in `gitops/`. Read-only.
- It does not advance autonomously to the next phase — that's the `BUILD-SPEC.md` single-paste workflow's job.
- It does not score components — that's `/score-component`.
