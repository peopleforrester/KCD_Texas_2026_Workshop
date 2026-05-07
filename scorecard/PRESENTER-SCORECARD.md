# KCD Texas 2026 — Presenter Scorecard

**Workshop:** "The 90-Minute IDP" • **Date:** May 15, 2026

This is the live, on-stage scorecard the presenter fills in **on the projector** as the build progresses. Different artifact from the per-attendee `SCORECARD-TEMPLATE.md`:

- **Student scorecard** = each attendee's personal record. Two scoring dimensions per phase (Toil Reduced, Integration), plus a wrap-up reflection that includes a one-time Usability rating. ~60 of these get filled out independently in the room.
- **Presenter scorecard** (this file) = single canonical scorecard the presenter fills live, **three** dimensions per component (Install, Integration, Usability), visible to the room. The room sees one scorecard fill in real time while filling their own private one alongside.

Both feed the wrap-up discussion. The student scorecards are aggregable for a follow-on talk; this presenter scorecard is the talk's anchor artifact.

---

## How to score live

Three dimensions, each on a 1–10 scale, for each component. Score them **independently** — AI can install a component cleanly (high Install) and produce something that does nothing useful (low Integration), or install it cleanly with all integrations green and still produce something a human can't actually use (low Usability).

| Dimension | What it measures | Score `10` looks like | Score `1` looks like |
|---|---|---|---|
| **Install** | Did Helm install / kubectl apply succeed end-to-end with the AI-generated config, no human rewrite? | Single prompt, single install, all pods Running. | Multiple correction cycles, manual chart-version archaeology, image registry workarounds. |
| **Integration** | Does the component do its job *in concert with the others* — not just "is it Running"? | Kyverno policies fire on real pods; Grafana shows populated dashboards; Backstage's catalog renders; ArgoCD reconciles drift in seconds. | Pods are Running but the feature doesn't work end-to-end. Policies don't fire, dashboards are empty, catalog is broken. |
| **Usability** | Could a developer actually use this on Monday morning to ship a service? Or is this an installed-but-useless artifact? | A new developer can self-serve a deploy through the platform without filing a ticket. | "Installed but I wouldn't hand this to anyone." Documentation missing, key flows broken, requires platform-team intervention to do anything real. |

Plus operational metrics:

- **Cycles**: distinct corrective prompts you sent Claude during this component (count, not severity).
- **AI time**: minutes from prompt-paste to verification-passing.

---

## Live Scorecard

Fill in **per phase** as you build. Don't backfill at the end; the live capture is the point.

| Phase / Component | Install (1–10) | Integration (1–10) | Usability (1–10) | Cycles | AI time | Notes |
|---|---:|---:|---:|---:|---:|---|
| **Phase 1 — ArgoCD bootstrap + app-of-apps** |   |   |   |   |   |   |
| **Phase 2 — Kyverno** (admission controller install) |   |   |   |   |   |   |
| **Phase 2 — Kyverno policies** (3 ClusterPolicies fire on real pods) |   |   |   |   |   |   |
| **Phase 3 — kube-prometheus-stack** (Prom, Grafana, kube-state-metrics) |   |   |   |   |   |   |
| **Phase 3 — Grafana dashboards** (populated with cluster metrics) |   |   |   |   |   |   |
| **Phase 4 — Backstage** (portal up, catalog visible, scaffolder reachable) |   |   |   |   |   |   |
| **Totals / Average** |   |   |   |   |   | — |

Six rows for six narrative beats. If Phase 4 (Backstage) goes sideways — and it's the most likely component to do so — you score what you got, narrate the failure honestly, and move on. A 4/10 Install with a frank explanation of why is more interesting data than a missing row.

---

## Reference baseline (kubeauto, overnight build)

For context: when this same stack was built end-to-end overnight in `kubeauto-ai-day` (single builder, no time pressure), the per-component results were:

| Component | Install | Integration | Cycles | AI time |
|---|---:|---:|---:|---:|
| ArgoCD install | 8 | 9 | 0 | 8 min |
| App-of-apps | 9 | 9 | 1 | 4 min |
| Kyverno install | 7 | — | 3 | 10 min |
| Kyverno policies | 9 | 9 | 1 | 5 min |
| kube-prometheus-stack | 8 | 8 | 1 | 8 min |
| Grafana dashboards | 9 | 9 | 0 | 3 min |
| Backstage | 7 | 7 | 1 | 10 min |

(*Source:* `kubeauto-ai-day/spec/SCORECARD.md`. Usability wasn't scored in the overnight build — that's what makes today's data interesting. Cycles and AI time are direct.)

The kubeauto numbers are a baseline, not a target. **Workshop conditions (live, time pressure, audience) routinely produce different scores.** That's the point — the variance between "Michael alone overnight" and "Michael with 60 people watching the timer" is the data.

---

## Closing the talk

After the final phase scores are in, average across columns to produce the headline number. Three plausible storylines:

- **Install ≫ Integration ≫ Usability.** AI can install almost anything; it's bad at making things work together; it's worst at making things human-usable. (Most likely outcome — and the most honest one.)
- **Install ≈ Integration > Usability.** AI is good at the technical layer but the platform layer is still where humans add the most value.
- **All three high.** Either today went unusually well or the scoring was generous; flag explicitly so the data isn't laundered.

Whichever pattern shows up, that's the talk's payoff: the implementation layer didn't disappear so much as compress. Integration and usability are where the engineering work moved.

---

## After the talk

This file is a *single canonical record*. Save the filled-in version (with date, the actual scores) into `scorecard/results/presenter-2026-05-15.md` (create the `results/` directory if needed) and commit. Future replicators (Accenture, others running this workshop format) can compare their results against yours to see whether the patterns repeat across rooms.
