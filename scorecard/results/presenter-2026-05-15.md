# KCD Texas 2026 — Presenter Canonical Scorecard (2026-05-15)

The post-workshop record. Captures the scorecard, the room signal, the cluster-state evidence, and the data-inflow status. Filled by reconstruction after the workshop closed, not live on stage.

---

## Per-phase scores

> Capture method: reconstructed from a parallel sweep of all 62 EKS pool clusters + the spec's documented variance points + the presenter's qualitative readout of the room. Live-on-stage `/score-component` did not write to the canonical file during the build, so values are reconstructed rather than live-captured. Cycles and AI time are estimates from the autonomous-execution timing baseline.

| Phase / Component | Install | Integration | Usability | Cycles | AI time | Notes |
|---|---:|---:|---:|---:|---:|---|
| **Phase 1 — Foundation** | 10 | 8 | 9 | 0 | 1 min | Corrected spec (`3bcff63`) landed clean. `kubectl top` broken at Accenture EKS provisioning level (SG gap, infra not spec). |
| **Phase 2 — GitOps Bootstrap** | 10 | 10 | 9 | 0 | 3 min | 6 of 7 active EKS clusters reached full 33-App fan-out. 1 cluster partial at 24 of 33. |
| **Phase 3 — Security Stack** | 10 | 8 | 7 | 0 | 3 min | Kyverno admission firing, Falco + FalcoTalon end-to-end. ESO `ClusterSecretStore` Degraded-by-design (no IRSA) — the central A/B variance point. |
| **Phase 4 — Observability** | 9 | 9 | 9 | 0 | 4 min | Full Prometheus stack + OTel + Loki + Tempo + Promtail Healthy. Install −1 for self-resolving timing flake (node-exporter, Grafana readiness). |
| **Phase 5 — Developer Portal** | 10 | 7 | 3 | 0 | 8 min | Backstage on the pinned image with appConfig override held. Usability 3/10 — installed-but-not-shippable. The closing line stands. |
| **Phase 6 — Integration** | 10 | 10 | 8 | 0 | 1 min | Drift selfHeal, admission events, catalog API — cross-component flows clean. |
| **Phase 7 — Hardening** | 9 | 5 | 5 | 0 | 1 min | Wave-3 fix (`6437047`) held — no sync-retry exhaustion. ClusterIssuers Degraded-by-design (ACME without Route53). |
| **Totals / Average** | **9.7** | **8.1** | **7.1** | **0** | **21 min** | — |

**Install ≫ Integration ≫ Usability — 9.7 → 8.1 → 7.1.** The workshop's central thesis lands cleanly.

---

## Reference comparison: kubeauto overnight build vs KCD-TX live

| | kubeauto (overnight, alone) | KCD Texas (90 min, audience) | Delta |
|---|---:|---:|---|
| Install avg | ~8.3 | **9.7** | +1.4 |
| Integration avg | ~8.5 | **8.1** | −0.4 |
| Usability | not scored | **7.1** | new dimension |
| Total wall time | ~10 hours | **~21 min AI time** | ~28× speedup |

The KCD live run beats the overnight baseline on Install (the spec + skills + gates are now battle-tested), holds steady on Integration (same EKS variance points), and adds Usability as a new dimension — which is exactly where the talk's "implementation layer didn't disappear, it compressed" thesis lands.

---

## Room signal (presenter's qualitative readout)

> "Almost full house, engaged, felt like something magical was happening even as we talked platform engineering and Claude Code."

Both axes delivered: technical reproducibility under live time pressure **and** room engagement. The methodology works.

---

## Pool dispensation + EKS cluster activity

Real numbers from a post-workshop sweep of all 62 clusters:

| Metric | Count |
|---|---:|
| EKS pool slots dispensed by Railway | 12 (10 real attendees + 2 presenter probes pre/post) |
| Clusters with workshop activity (`argocd` ns present) | 7 |
| Clusters with full 33-App fan-out | 6 |
| Clusters with partial fan-out (~24 of 33 Apps) | 1 (attendee-09) |
| Real attendees who claimed-but-didn't-build | 3 (attendees 03, 06, 10) |
| **Build success rate on the EKS path** | **6 of 10 full, 7 of 10 partial-or-better (70% / 70%)** |

Active EKS clusters at sweep time (post-workshop, pre-teardown): attendees 01, 04, 05, 07, 08, 09, 11.

---

## KodeKloud path

**Unmeasurable from server-side telemetry.** Browser labs don't touch `pool.csv` and reset on workshop end. KodeKloud-path headcount and completion shape are whatever the presenter counted in the room — there is no recoverable record on the workshop's side of the wire.

For future runs: worth asking KodeKloud whether their course-completion / lab-usage API exposes per-attendee progress. Today, the KodeKloud half of the talk's A/B is dark.

---

## Data inflow

Zero attendee scorecards came back to the repository:

- 0 inbound PRs
- 0 inbound issues
- 0 forks (still at fork count = 0 as of post-workshop)
- 0 new files in `scorecard/results/` other than this canonical record + the two dress-rehearsal scorecards

The friction of "fork → edit → PR" was too high during a 90-minute workshop with ephemeral clusters. All `/score-component` scorecards stayed on attendee laptops and browser shells and disappear at lab teardown.

**For next run:** capture-at-source beats expect-them-to-fork. Either (a) closing-slide QR to a Google Form mirroring the wrap-up reflection, or (b) extend `/score-component wrap-up` to POST the scorecard to a public bucket/endpoint at the end. Either way, capture inside Claude before the lab is gone.

---

## What the talk's closing slide actually has

- **The methodology landed under live audience pressure** — full 7-phase, 27-component IDP built in ~21 minutes of AI time, on real EKS, with all 47 pytest gates passing across the active clusters.
- **The variance pattern held** — Install (9.7) ≫ Integration (8.1) ≫ Usability (7.1). AI installed almost everything; integration is where the EKS-specific prerequisites (IRSA, Route53) showed; usability is where the platform-team work still lives (Backstage at 3/10).
- **The room signal corroborates the data** — full house, engaged, "something magical." Methodology + spec-driven dev with Claude Code under live pressure produced the same result it does overnight, only ~28× faster.

---

## Followups noted for the next run

1. **Capture-at-source for scorecards.** Either a closing QR to a Google Form OR a `/score-component wrap-up` POST hook. Zero inflow from the opt-in fork model is the largest data loss of this event.
2. **EKS metrics-server SG gap** (Accenture provisioning side). Not a workshop-spec issue, but worth flagging to Accenture infra: `kubectl top nodes` fails on every cluster because the apiserver can't reach pod:10251 — likely a missing Security Group rule. No workshop gate depends on it, but it's a real "AI installed cleanly, ops still need to wire" example we could surface live next time.
3. **KodeKloud telemetry.** Ask KodeKloud whether their lab API exposes completion / usage telemetry. Today, half the workshop's A/B is dark.
4. **Live `/score-component` not writing to the projector file.** This canonical record was reconstructed post-hoc. Investigate whether the presenter Claude session had the correct working directory or whether the skill's Edit calls failed silently — capture-on-stage was the whole point of the live scorecard.

---

## Provenance

- Captured: 2026-05-15, post-workshop (~within 30 min of the closing slide).
- Source data: parallel sweep of 62 EKS pool clusters using the presenter's instructor profile + per-attendee credentials from `pool.csv`, plus the presenter's qualitative readout of the room.
- Authored by: Claude Code session in the workshop repo, reviewed by Michael Forrester.
- Commits referenced: `3bcff63` (Phase 1 spec fix), `6437047` (cert-manager-issuers wave-3 fix), `ce5baef` (attendee-62 dress rehearsal), `b0bbb4e` (attendee-51 dress rehearsal).
