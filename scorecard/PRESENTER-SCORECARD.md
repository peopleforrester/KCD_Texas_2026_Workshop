# KCD Texas 2026 — Presenter Scorecard

**Workshop:** "The 90-Minute IDP" • **Date:** May 15, 2026

This is the live, on-stage scorecard. **The presenter doesn't hand-edit this file either.** After each phase, Michael runs `/score-component phase-N` from the projector terminal — Claude asks him the five values and writes the row in real time, visible to the room. Different artifact from the per-attendee `SCORECARD-TEMPLATE.md`:

- **Student scorecard** = each attendee's personal record. Three scoring dimensions per phase (Install, Integration, Usability), plus a wrap-up reflection. ~60 of these get filled out independently in the room via `/score-component` running in each attendee's Claude.
- **Presenter scorecard** (this file) = single canonical scorecard Claude writes for the presenter via `/score-component`, live on stage, same three dimensions, visible to the room. The room watches Michael speak the five values out loud and Claude writes the row into this file in real time — each attendee runs `/score-component` in their own Claude on the same beat.

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

## Live Scorecard — KCD Texas 2026 (filled post-workshop, 2026-05-15)

> **Note on capture method.** This scorecard was filled *after* the workshop from objective cluster-state evidence (a sweep across all 62 EKS pool clusters), the spec's documented variance points, and the room's qualitative signal as reported by the presenter. On-stage `/score-component` did not write to this file during the live build, so values are reconstructed rather than live-captured. Cycles + AI time are estimates from the autonomous-execution timing baseline; the presenter is the only source for exact numbers and may amend.

| Phase / Component | Install (1–10) | Integration (1–10) | Usability (1–10) | Cycles | AI time | Notes |
|---|---:|---:|---:|---:|---:|---|
| **Phase 1 — Foundation** (cluster Ready, 9 namespaces, metrics-server) | 10 | 8 | 9 | 0 | 1 min | Corrected spec (commit `3bcff63`) landed clean across all 7 active clusters. Integration −2 because `kubectl top` is broken at the Accenture EKS provisioning level (SG gap); not workshop-spec-fixable, no gate depends on it. |
| **Phase 2 — GitOps Bootstrap** (ArgoCD + app-of-apps → 32 children) | 10 | 10 | 9 | 0 | 3 min | helm install argocd@9.5.x + app-of-apps fanned out cleanly in 6 of 7 active clusters. 1 cluster reached 24 of 33 children (attendee-09 — partial reconcile at workshop end). |
| **Phase 3 — Security Stack** (Kyverno + 3 policies, Falco + rules, Falcosidekick, FalcoTalon, ESO, RBAC, NetPol) | 10 | 8 | 7 | 0 | 3 min | Kyverno admission firing, Falco DS + Falcosidekick + FalcoTalon all Healthy. ESO `ClusterSecretStore` Degraded-by-design (no IRSA) — the workshop's central A/B variance point landed exactly as designed. |
| **Phase 4 — Observability** (Prom + Grafana + OTel + Loki/Tempo/Promtail) | 9 | 9 | 9 | 0 | 4 min | Full Prometheus stack + OTel + Loki + Tempo + Promtail Healthy. Install −1 for the timing flake observed in cluster-62 rehearsal (node-exporter + Grafana readiness) — self-resolves but visible. |
| **Phase 5 — Developer Portal** (Backstage, catalog, templates, demo apps in catalog) | 10 | 7 | 3 | 0 | 8 min | Backstage Pod Running on the pinned image (`ghcr.io/backstage/backstage:1.30.2`); the appConfig override prevented the Kubernetes-plugin startup crash. Usability 3/10 stays — catalog is seed-only, no Software Templates. **The "installed-but-not-shippable" closing line stands.** |
| **Phase 6 — Integration** (drift selfHeal + admission events + Falco→Talon end-to-end) | 10 | 10 | 8 | 0 | 1 min | All cross-component flows observed Healthy. Drift selfHeal under 60s is the moment that visibly lands for the audience. |
| **Phase 7 — Hardening** (cert-manager, ClusterIssuers, Quotas + PDBs) | 9 | 5 | 5 | 0 | 1 min | cert-manager + CRDs installed clean; the wave-3 fix (commit `6437047`) held — no sync-retry exhaustion on the live run. ClusterIssuers Degraded-by-design (ACME without Route53), Certificate-Ready test skipped on EKS path as documented. |
| **Totals / Average** | **9.7** | **8.1** | **7.1** | **0** | **21 min** | — |

**Install ≫ Integration ≫ Usability** — the workshop's central thesis lands cleanly: **9.7 → 8.1 → 7.1**. AI installed almost everything; integration is where the EKS-specific variance points (IRSA, Route53) show; usability tops out at "platform installed, developer-experience layer still where the engineering work lives" — Phase 5 (Backstage at 3/10 Usability) is the talk's closing punctuation.

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

This file is a *single canonical record*. After the workshop, ask Claude to copy this file to `scorecard/results/presenter-2026-05-15.md` (create the `results/` directory if needed) and commit. Future replicators (Accenture, others running this workshop format) can compare their results against yours to see whether the patterns repeat across rooms.
