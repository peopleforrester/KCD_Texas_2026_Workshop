# /validate-phase $ARGUMENTS

Run the pytest test gate for Phase $ARGUMENTS. Used in two contexts:

- **On the presenter's Claude:** to run the gate live so the audience sees pass/fail with structured output
- **On a student's Claude:** to verify their cluster is in the same state as Michael's before scoring

## Your job

1. Open `spec/phases/phase-0$ARGUMENTS-*.md` to find the **Test gate** reference
2. Run: `pytest tests/test_phase_0$ARGUMENTS_*.py -v`
3. Report the structured pytest output verbatim (or summarize if very long)

Pytest output is the gate. If pytest exits 0, every test passed and the user can output `<promise>PHASE_${ARGUMENTS}_DONE</promise>`. If pytest exits non-zero, name the failed tests and surface the assertion errors.

## Diagnosis when tests fail

For each failing test:
1. Read the assertion message — pytest test names are descriptive (e.g., `test_app_of_apps_targets_main_branch`)
2. Pull additional state if useful: `kubectl describe`, `kubectl logs`, `kubectl get events --sort-by=.lastTimestamp`
3. Match the failure to the phase spec's **Known failure modes** — most failures are listed there
4. **Name the pattern out loud (if presenter mode).** "This is the no-default-image trap — let me show you in the values block what's missing." That's the talk.

If the failure doesn't match a known pattern: say so honestly. "I haven't seen this one before. The assertion says X. Let me check Y." Don't guess wildly on stage.

## When a student's tests fail but the presenter's pass

Most likely causes (in order):
1. Their cluster hasn't reconciled yet (wait 30–60s, re-run)
2. Their AWS connectivity dropped briefly
3. They ran the gate before applying the bootstrap

Suggest those in order, then raise the issue with Michael during the next gate pause if none apply. (Michael is alone for this workshop — no TAs — so the gate-pause windows are the only time individual troubleshooting can happen.)

## What this command does NOT do

- Edit any manifest. Diagnosis is read-only.
- Push to git. Read-only repo.

If a fix requires editing a manifest, that's a `/build-phase` action — surface the change and let the user decide.
