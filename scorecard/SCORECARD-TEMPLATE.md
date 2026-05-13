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

Fill one row at the end of each phase, *as you go* — don't backfill from memory at the end. Same dimensions as the live presenter scorecard you'll see on the projector; your numbers and the room's will be visible side by side at the close.

| Phase / Component | Install (1–10) | Integration (1–10) | Usability (1–10) | Cycles | AI time | Notes (1 line) |
|---|---:|---:|---:|---:|---:|---|
| Phase 1 — ArgoCD bootstrap + app-of-apps | | | | | | |
| Phase 2 — Kyverno install | | | | | | |
| Phase 2 — Kyverno policies | | | | | | |
| Phase 3 — kube-prometheus-stack | | | | | | |
| Phase 3 — Grafana dashboards | | | | | | |
| Phase 4 — Backstage | | | | | | |
| **Totals / Average** | | | | | | — |

### How to fill each column

- **Install (1–10):** Did the manifest, after applying, bring the component up healthy? First try, no rewrites? That's a 10. Three correction cycles, image registry workaround, manual chart-version archaeology? That's a 4. Score what *happened*, not what the playbook implies should happen.
- **Integration (1–10):** A *separate* dimension from Install. AI can install a component cleanly and still produce something that doesn't actually work end-to-end. Score whether the component does the thing it's supposed to do, in concert with everything around it. Per-phase examples:
  - Phase 1: did the five child Applications auto-discover from your bootstrap and start installing without intervention?
  - Phase 2 (install row): is the admission controller reachable / webhook firing?
  - Phase 2 (policies row): did Kyverno actually reject a non-compliant pod *and* allow a compliant one? Not "did it install" — did the policy fire correctly at admission time?
  - Phase 3 (kube-prom-stack row): are Prometheus + Grafana up and reachable; is Prometheus scraping ArgoCD?
  - Phase 3 (Grafana dashboards row): are the dashboards actually populated with cluster metrics, or empty?
  - Phase 4: did Backstage start, show a populated catalog, and stay up under poking?
- **Usability (1–10):** Could a developer on your team drive *this component* on Monday morning?
  - `10` = production-ready as-is; junior engineer could pick it up tomorrow.
  - `5` = the bones are right but a half-day of plumbing to make it real.
  - `1` = installed-but-useless; nice toy, can't ship anything through it.
  - Phase 4's Usability is almost always low for the workshop scorecard — community image catalog is read-only and not wired to your cluster. That's honest, not a failing.
- **Cycles:** Count the number of **distinct corrective prompts** you sent Claude — not the number of issues addressed in a single prompt. Initial prompt + zero corrections = `0`. Initial prompt → "fix-the-labels-and-limits-and-probes" (one corrective prompt addressing three issues) → success = `1`. Initial prompt → fix-1 → fix-2 → success = `2`.
- **AI time (min):** Wall-clock minutes from when you pasted the phase prompt to when the test gate passed. Round to the nearest minute; if unsure, round down. Don't count time you stepped away from the keyboard (bathroom, water, side conversations).
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

### 3. How usable is what you've got?

Look at the IDP running on your cluster right now. Forget for a moment whether it was easy or hard to install. **Could you actually deploy a service through this platform tomorrow morning?** Could a teammate who didn't attend this workshop?

Usability score (1–10): ____

- `10` = production-ready as-is; I'd hand this to a junior engineer and they'd ship.
- `5` = the bones are right but I'd need a half-day to make it actually usable for my team.
- `1` = installed-but-not-usable; nice tour, can't ship anything through it.

One sentence — what's the single biggest barrier between this platform and someone using it Monday morning?

____________________________________________________________

### 4. Where AI helped most today

The phase or step where Claude made you most productive — what was it, and what specifically about it worked?

____________________________________________________________

### 5. Where AI struggled today

The phase or step where Claude got the most things wrong — what was it, and what was the failure pattern? (Wrong chart values, hallucinated API, deprecated pattern, missed context, etc.)

____________________________________________________________

### 6. One thing you'll take back to your team

You don't have to have a "lesson." If you do, what is it?

____________________________________________________________

---

## Submission (Optional)

If you're willing to share your scorecard so we can publish aggregated workshop results, drop this file into your workshop repo at `scorecard.md` before you leave the venue. We'll collect from each repo and anonymize the published version (no names, no cluster IDs).

If you'd rather keep yours private, just close the file. The point of this exercise is mostly for you — what you noticed about your own AI-assisted workflow during 90 minutes of pressure.

Either way: thanks for being part of the workshop.
