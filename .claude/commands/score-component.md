# /score-component $ARGUMENTS

Score the component or run the wrap-up reflection. **$ARGUMENTS** is one of:

- A phase identifier — `phase-1`, `phase-2`, … `phase-7` (or a component name that matches a scorecard row, e.g. `argocd`, `kyverno`, `backstage`). → phase-scoring mode.
- `wrap-up` (or empty) → wrap-up reflection mode (six questions, end of workshop).

The student never hand-edits the scorecard file. You do the writing.

When run on the presenter's Claude, this updates the on-stage `PRESENTER-SCORECARD.md`. When run on a student's Claude, this updates their student `SCORECARD-TEMPLATE.md`.

---

## Phase-scoring mode

### Your job

1. Open the appropriate scorecard:
   - `scorecard/PRESENTER-SCORECARD.md` if Michael runs this command
   - `scorecard/SCORECARD-TEMPLATE.md` if a student runs this command
2. Find the row matching **"$ARGUMENTS"** (fuzzy-match the phase number or component name against the row labels — students may pass `phase-3`, `security`, or `kyverno` for the same row).
3. Recall what happened during the just-completed phase (Install gates passed? On first try or after N corrections? What did the diff against ground truth show? Did integration work end-to-end? Was the UI / catalog / dashboard actually usable?)
4. Ask the user for the five values, one prompt:
   - Install (1–10)
   - Integration (1–10)
   - Usability (1–10)
   - Cycles (count of distinct corrective prompts; initial-prompt-only = 0)
   - AI time (minutes from paste to gate-passing)
   - Optional 1-line note
5. Write the row into the scorecard file using the Edit tool. Preserve the table's column alignment.
6. Summarize: `Phase N scored: Install=X, Integration=Y, Usability=Z, Cycles=N, AI time=M min.`

### The three dimensions (presenter or student — same model)

| Dimension | What it measures | A 10 looks like |
|---|---|---|
| **Install** | Did Claude generate a manifest that, after applying, brought the component up healthy? | Pods Running, no rewrites, manifest correct first try, structurally matches ground truth |
| **Integration** | Does it work *with* the other components? | Sync waves right, ArgoCD discovers it, webhook scoped right, scrape working, no policy collisions |
| **Usability** | Could a developer drive this Monday morning? | Clear UI, sensible defaults, the right things are discoverable |

---

## Wrap-up mode (`/score-component wrap-up`)

Run this once, at the end of the workshop. Walks the student through the six wrap-up reflection questions and writes the answers into `scorecard/SCORECARD-TEMPLATE.md`'s "Wrap-Up Reflection" section.

### Your job

1. Open `scorecard/SCORECARD-TEMPLATE.md`.
2. Ask each of the six questions in order, one at a time. Wait for each answer before asking the next:
   1. **Manual time estimate** — if they'd built this by hand, no AI, fresh cluster, honest guess in hours or days.
   2. **Did AI shift the toil?** — No / Partial / Yes, plus one sentence on which phase felt most/least like babysitting.
   3. **How usable is what you've got?** — Usability score 1–10, plus one sentence on the single biggest barrier between this platform and shipping a service through it Monday morning.
   4. **Where AI helped most** — one specific moment.
   5. **Where AI struggled** — one specific failure pattern.
   6. **One thing you'll take back to your team** — optional, blank is fine.
3. Write the answers into the corresponding sections of `scorecard/SCORECARD-TEMPLATE.md`.
4. Also compute and write the averages row (`Totals / Average`) across all filled phase rows.
5. Summarize: total filled phases, averages, and a one-line "submission optional — see the bottom of the file" reminder.

---

## Rules (both modes)

- **Don't suggest scores or sample answers.** The user picks the numbers and writes the words. Your job is to make capture easy by recalling what happened, not by anchoring the response.
- **Don't soften.** If the chart installed cleanly but Grafana showed "No data" for 60 seconds, that's a high Install + low Integration. The variance is the talk's payoff.
- **If a phase failed entirely** (e.g., Backstage Pod didn't reach Running), score what happened. A 3/10 Install with one line of "Pod stuck in CrashLoopBackOff with `createServiceBuilder is not a function` because Claude defaulted to an older image" is more valuable than a missing row.
- **Edit the file with the Edit tool**, not by asking the user to paste their entries somewhere. The whole point of this command is the user never touches the markdown.

## What this command does NOT do

- Modify any manifest
- Re-run any test gate (that's `/validate-phase`)
- Push or commit the scorecard (presenter saves their canonical scorecard to `scorecard/results/presenter-2026-05-15.md` after the workshop; students opt-in to share via fork or the closing-slide channel)
