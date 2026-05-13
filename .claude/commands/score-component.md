# /score-component $ARGUMENTS

Walk the user through scoring the component: **$ARGUMENTS**

When run on the presenter's Claude, this updates the on-stage `PRESENTER-SCORECARD.md` row. When run on a student's Claude, this updates their student `SCORECARD-TEMPLATE.md` row.

## Your job

1. Open the appropriate scorecard:
   - `scorecard/PRESENTER-SCORECARD.md` if Michael runs this command
   - `scorecard/SCORECARD-TEMPLATE.md` if a student runs this command
2. Find the row for **"$ARGUMENTS"**
3. Recall what happened during the just-completed phase (Install gates passed? On first try or after N corrections? What did the diff against ground truth show? Did integration work end-to-end? Was the UI / catalog / dashboard actually usable?)
4. Ask for the values across the three dimensions and the operational metrics
5. Write the row into the scorecard file
6. Summarize: "Phase scored: Install=X, Integration=Y, Usability=Z, Cycles=N, AI time=M min."

## The three dimensions (presenter or student — same model)

| Dimension | What it measures | A 10 looks like |
|---|---|---|
| **Install** | Did Claude generate a manifest that, after applying, brought the component up healthy? | Pods Running, no rewrites, manifest correct first try, structurally matches ground truth |
| **Integration** | Does it work *with* the other components? | Sync waves right, ArgoCD discovers it, webhook scoped right, scrape working, no policy collisions |
| **Usability** | Could a developer drive this Monday morning? | Clear UI, sensible defaults, the right things are discoverable |

## Rules

- **Don't suggest scores.** Michael (or the student) picks the numbers. Your job is to make scoring easy by recalling what happened, not by anchoring it.
- **Don't soften.** If the chart installed cleanly but Grafana showed "No data" for 60 seconds, that's a high Install + low Integration. The variance is the talk.
- **If a phase failed entirely** (e.g., Backstage Pod didn't reach Running), score what happened. A 3/10 Install with one line of "Pod stuck in CrashLoopBackOff with `createServiceBuilder is not a function` because Claude defaulted to an older image" is more valuable to the workshop's central claim than a missing row.

## What this command does NOT do

- Modify any manifest
- Re-run any test gate (that's `/validate-phase`)
- Push the scorecard anywhere (presenter saves their canonical scorecard to `scorecard/results/presenter-2026-05-15.md` after the workshop; students opt-in)
