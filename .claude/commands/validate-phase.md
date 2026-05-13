# /validate-phase $ARGUMENTS

Run the test gate for Phase $ARGUMENTS. Used in two contexts:

- **On the presenter's Claude:** to run the gate live so the audience sees pass/fail in real time
- **On a student's Claude:** to verify their cluster is in the same state as Michael's before scoring

## Your job

1. Open `spec/phases/phase-0$ARGUMENTS-*.md`
2. Find the **"The test gate"** section
3. Run each `kubectl` (or `helm`, `curl`) command in order
4. Capture each output, compare to the **Expected** result in the spec
5. Report in this format:

```
Phase $ARGUMENTS test gate:

✓ Gate 1: kubectl get pods -n <ns> — all Running
✓ Gate 2: kubectl get application <name> -n argocd — Synced/Healthy
✗ Gate 3: kubectl run test-bad ... — was accepted, expected admission denial
✓ Gate 4: kubectl run test-good ... — accepted

3/4 gates passed.
```

6. If all pass: confirm the user can output `<promise>PHASE_${ARGUMENTS}_DONE</promise>` and move to scoring with `/score-component`.
7. If any fail: do not confirm the promise. Diagnose first.

## Diagnosis (when running live on the presenter's Claude)

For each failed gate:
1. Pull relevant state: `kubectl describe`, `kubectl logs`, `kubectl get events --sort-by=.lastTimestamp`
2. Match the failure to a **Known failure mode** in the phase spec — most failures are listed there
3. **Name the pattern out loud.** The audience is watching the projector. "This is the no-default-image trap — let me show you in the values block what's missing." That's the talk.

If the failure doesn't match a known pattern, say so honestly. "I haven't seen this one before. Logs say X. Let me check Y." Don't guess wildly on stage.

## Diagnosis (when run by a student catching up)

Same diagnosis, less narration. If a student's gate fails when Michael's passed, the most likely cause is:

- They're behind by a phase — their cluster hasn't reconciled yet (wait 30–60s)
- Their AWS connectivity dropped briefly
- They ran the gate before applying — re-check the bootstrap is in place

Suggest those in order, then escalate to a TA if none apply.

## What this command does NOT do

- Edit any manifest. Diagnosis is read-only.
- Run pytest. Workshop gates are kubectl-only by design.
- Push to git. Read-only repo.

If a fix requires editing a manifest, that's a `/build-phase` action — surface the change and let the user decide.
