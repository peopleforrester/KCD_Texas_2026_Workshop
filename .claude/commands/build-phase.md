# /build-phase $ARGUMENTS

You are driving Phase $ARGUMENTS of the KCD Texas 90-Minute IDP workshop. Michael (the presenter) has pasted this command at the start of a phase. The audience is watching the projector. Students are running their own Claude on their own clusters in parallel.

## Your job in this command

1. **Read** `spec/BUILD-SPEC.md` for the workshop framing
2. **Read** `spec/phases/phase-0$ARGUMENTS-*.md` for this phase's goal, prompt, test gate, known failure modes
3. **Read** the skill file referenced by the phase spec — before generating anything
4. **Walk through the architecture** when the phase spec asks you to (the "first, explain..." step). The audience is reading along on the projector; explanations are part of the talk.
5. **Generate** the manifest(s) the phase asks for, saved to `~/my-<component>.yaml`
6. **Diff** the generated manifest against the pre-committed ground truth at `gitops/apps/<component>.yaml` or `gitops/manifests/`. Walk through every difference out loud — what's structural vs stylistic vs a real omission.
7. **Read out the test gate commands** so Michael can paste them. The presenter runs the gate; you analyze the output.
8. **Diagnose failures honestly** using the phase spec's "Known failure modes" section. Don't paper over a failed gate — the failure is part of the talk.

## Completion

When all test-gate commands return what the phase spec says they should, output:

```
<promise>PHASE_${ARGUMENTS}_DONE</promise>
```

**Do not fake the promise.** A faked promise undermines the workshop's central claim.

## Rules specific to live presentation

- **Read the skill file first.** Every skill warns about a specific trap. Skipping the skill produces deprecated patterns that the audience will see live.
- **Generate to `~/my-<component>.yaml`.** Not into `gitops/` — the repo is read-only during the workshop.
- **Diff is the educational moment.** Don't move past the diff quickly. The audience learns more from "here's where my generated manifest is missing `ServerSideApply=true`" than from a successful build.
- **Narrate failures by name.** When something fails, match it to the phase spec's Known Failure Modes and name the pattern out loud. "This is the no-default-image trap — let me show you in the values block what's missing."
- **Do not suggest scores.** Michael scores on the live scorecard with the room watching. Your role is honest comparison and clean diagnosis.

## What this command does NOT do

- It does not `git push`. Students don't push.
- It does not modify files in `gitops/`. Read-only.
- It does not run pytest. The test gates are kubectl commands; the audience can read them on the projector and run them on their own clusters.
- It does not score components — that's `/score-component`.

## When students run this independently

A student who has fallen behind during a phase pause can run `/build-phase N` on their own Claude to catch up. They'll see the same prompts, the same generated manifest, the same diff against ground truth. Their cluster reconciles from the same pre-committed `gitops/` tree.

If a student runs `/build-phase 2` while Michael is on Phase 3, that's fine — Claude reads only Phase 2's spec and skill, no coupling.
