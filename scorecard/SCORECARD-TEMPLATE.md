# KCD Texas 2026 — Workshop Scorecard

**Workshop:** "The 90-Minute IDP" • **Date:** May 15, 2026

Fill this in **as you go**, not after the workshop. Reconstructing scores from memory at the end is the kind of thing that makes the data useless. Each phase's row should take ~30 seconds to fill in once you've finished that phase's verification step.

---

## Who You Are (optional)

You can leave any of these blank. Submission is opt-in.

- **Name (or handle):** ___________________________
- **Cluster:** kcd-texas-student-___
- **Workshop repo URL:** ___________________________
- **Years of Kubernetes experience:** ___________________________
- **Have you used Claude Code before today?** Yes / No
- **Have you built an IDP before?** Yes / No

---

## Per-Phase Scores

Fill one row at the end of each phase. The four columns map 1:1 to the scorecard slot at the bottom of each phase in the playbook.

| Phase | AI time (min) | Correction cycles | Toil reduced (1–10) | Integration (1–10) | Tour / DIY | Notes (optional, 1 line) |
|---|---:|---:|---:|---:|:---:|---|
| 1 — ArgoCD / GitOps | | | | | | |
| 2 — Kyverno policies | | | | | | |
| 3 — Prometheus + Grafana | | | | | | |
| 4 — Backstage | | | | | | |
| **Totals / Average** | | | (avg) | (avg) | — | |

### How to fill each column

- **AI time (min):** Wall-clock minutes from when you pasted the phase prompt to when the verification command passed. Round to the nearest minute; if unsure, round down. Don't count time you stepped away from the keyboard (bathroom, refilling water, side conversations).
- **Correction cycles:** Count the number of **distinct corrective prompts** you sent to Claude — not the number of issues addressed in a single prompt. Initial prompt + zero corrections = `0`. Initial prompt → "fix-the-labels-and-limits-and-probes" (one corrective prompt addressing three issues) → success = `1`. Initial prompt → fix-1 → fix-2 → success = `2`.
- **Toil reduced (1–10):** Your honest estimate of how much manual *install* work AI eliminated for you in this phase.
  - `10` = AI did in minutes what would have taken me hours by hand, with no rework.
  - `5` = AI got me roughly half-way; I corrected significantly.
  - `1` = It would have been faster to do this myself from scratch.
  - Don't optimize for high scores — accurate scores are what's useful.
- **Integration (1–10):** A *separate* dimension from installation. AI can install a component cleanly and still produce something that doesn't actually work end-to-end. Score whether the component does the thing it's supposed to do, in concert with everything around it. Per-phase examples:
  - Phase 1: did the four child Applications auto-discover from your bootstrap and start installing without intervention?
  - Phase 2: did Kyverno actually reject a non-compliant pod *and* allow a compliant one? (Not "did it install" — did the policy fire correctly at admission time?)
  - Phase 3: are Grafana's default dashboards actually populated with cluster metrics, or empty? Is Prometheus scraping ArgoCD's metrics endpoint?
  - Phase 4: did Backstage start, show a populated catalog, and stay up under poking? (With the community image, you won't have working software templates — that's a known limitation, not a 0/10.)
- **Tour / DIY:** Mark whether you took the default Tour path for this phase or the optional DIY ("I built this") path.
- **Notes:** One line if anything stood out (a clever Claude move, a specific failure mode, a moment you almost gave up). Blank is fine.

---

## Wrap-Up Reflection

Fill this in **once**, after Phase 4. Keep it short — one or two sentences per prompt is enough.

### 1. Manual time estimate

If you'd had to build the same four components by hand, no AI, on a fresh cluster, your honest guess for how long it would have taken you:

____ hours / days

(There is no right answer. The reference build was ~12 hours of estimated manual work for a 7-phase platform. Your 4-phase scope is smaller; pick a number that feels true.)

### 2. Did AI shift the toil?

A common pattern with AI tools is that "writing the YAML" gets replaced with "debugging the AI's YAML" — same total time, just a different shape of work. Did that happen for you today?

- [ ] **No** — AI saved time without much friction.
- [ ] **Partial** — some phases were genuine wins, others felt like I was babysitting Claude.
- [ ] **Yes** — most of my time was correcting AI output. The toil moved, it didn't shrink.

One sentence on which phase felt most/least like toil-shifting:

____________________________________________________________

### 3. Where AI helped most today

The phase or step where Claude made you most productive — what was it, and what specifically about it worked?

____________________________________________________________

### 4. Where AI struggled today

The phase or step where Claude got the most things wrong — what was it, and what was the failure pattern? (Wrong chart values, hallucinated API, deprecated pattern, missed context, etc.)

____________________________________________________________

### 5. One thing you'll take back to your team

You don't have to have a "lesson." If you do, what is it?

____________________________________________________________

---

## Submission (Optional)

If you're willing to share your scorecard so we can publish aggregated workshop results, drop this file into your workshop repo at `scorecard.md` before you leave the venue. We'll collect from each repo and anonymize the published version (no names, no cluster IDs).

If you'd rather keep yours private, just close the file. The point of this exercise is mostly for you — what you noticed about your own AI-assisted workflow during 90 minutes of pressure.

Either way: thanks for being part of the workshop.
