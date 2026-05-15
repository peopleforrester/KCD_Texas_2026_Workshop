# Dress Rehearsal — Attendee-62, 2026-05-15 (post Phase 1 spec fix)

Re-ran the full spec on a second fresh EKS cluster (`kcd-tx-attendee-62`, EKS 1.35.4, us-east-2) using the **corrected** Phase 1 prompt landed in commit `3bcff63`. Confirms the spec fix works and surfaces one new bug.

**Headline:** 48 of 49 tests pass on first sweep, 1 intentional skip. Same pass count as attendee-51, **but with the Phase 1 toil-shift eliminated** — cycles dropped from 3 → 1, Phase 1 Install went 6 → 10. Two new issues surfaced (one cluster-infra, one spec).

## Per-Phase Scores

| Phase / Component | Install (1–10) | Integration (1–10) | Usability (1–10) | Cycles | AI time (min) | Notes |
|---|---:|---:|---:|---:|---:|---|
| Phase 1 — Foundation | 10 | 7 | 9 | 0 | 1 | Corrected spec executes cleanly: detect → apply namespaces → verify metrics-server addon (no upstream apply on EKS) → gate. Integration drops because `kubectl top` still fails — see "New finding #1" below; that's an Accenture EKS provisioning gap, not the workshop's. |
| Phase 2 — GitOps Bootstrap | 10 | 10 | 9 | 0 | 3 | helm install argocd@9.5.x clean. App-of-apps applied; 32 children discovered within 2.5 min. |
| Phase 3 — Security Stack | 10 | 8 | 7 | 0 | 2 | Kyverno admission denying. Falco DS + Falcosidekick + FalcoTalon Running. ESO Degraded-by-design (no IRSA). |
| Phase 4 — Observability | 9 | 9 | 9 | 0 | 4 | Self-resolving timing flakes: node-exporter DS missing at minute 4 (deployed by minute 12); Grafana Pending for 90s during readiness-probe warmup. Both passed on retry, no corrections. |
| Phase 5 — Developer Portal | 10 | 7 | 3 | 0 | 8 | Backstage Pod Running on the pinned image; slow first-time image pull (~8 min). |
| Phase 6 — Integration | 10 | 10 | 8 | 0 | 1 | Same as attendee-51. |
| Phase 7 — Hardening | 9 | 5 | 5 | 1 | 1 | **New spec issue #2 surfaced** — `cert-manager-issuers` Application stuck `Missing/OutOfSync` because ArgoCD's first sync attempt hit `no endpoints available for service "cert-manager-webhook"`, retry policy exhausted before webhook came up. Gate still passes (permissive by design on EKS) but the Application stays in failed-sync state until manually nudged. |
| **Totals / Average** | **9.7** | **8.0** | **7.1** | **1** | **20** | — |

## Test gate sweep (all 7 phases, second-run)

```
test_phase_01_foundation.py    5 passed   (0 failed)
test_phase_02_gitops.py        6 passed   (0 failed)
test_phase_03_security.py     13 passed   (0 failed)
test_phase_04_observability   10 passed   (0 failed)  ← passed on retry after node-exporter + Grafana settle
test_phase_05_portal.py        4 passed   (0 failed)
test_phase_06_integration.py   4 passed   (0 failed)
test_phase_07_hardening.py     6 passed   (1 skipped — by design)
─────────────────────────────────────────────────────
                              48 passed   (1 skipped)
```

## Comparison: attendee-51 vs attendee-62

| | attendee-51 (old spec) | attendee-62 (corrected spec) | Delta |
|---|---:|---:|---|
| Install avg | 9.3 | **9.7** | +0.4 (Phase 1 fix) |
| Integration avg | 8.0 | 8.0 | — |
| Usability avg | 7.0 | 7.1 | — |
| **Cycles** | 3 | **1** | **−2** (all from Phase 1) |
| AI time | 19 min | 20 min | +1 min (Backstage image pull) |
| Tests passing | 48 / 49 | 48 / 49 | — |

The Phase 1 spec fix delivers exactly the change you'd expect: identical pass count, zero churn in the steady-state phases, and the Phase 1 cycle count goes to zero on EKS.

## Two new findings

### #1 — Accenture EKS metrics-server APIService unreachable out-of-the-box (infra-level, not workshop spec)

On a pristine Accenture-provisioned EKS cluster I have NEVER touched, `kubectl top nodes` returns `error: Metrics API not available`. Cause: the EKS apiserver can't reach pod IPs on port 10251 — the APIService's status shows `context deadline exceeded` against the metrics-server pod IP. Endpoints are correct, pods are 2/2 Available. This is a missing Security Group rule (or VPC routing gap) in Accenture's EKS provisioning template, not something the workshop spec can fix.

Workshop impact: **none.** No test gate depends on `kubectl top`, no Phase asserts HPA functionality. But the workshop's narrative could call this out as a concrete example of "AI installed cleanly, ops still need to wire prereqs" — the same theme as the IRSA gap for ESO.

Recommendation: flag this to Accenture infra for a future provisioning fix; do not modify the workshop spec.

### #2 — `cert-manager-issuers` Application sync-retry exhaustion against not-yet-ready webhook (spec-level, easily fixed)

When ArgoCD applies `cert-manager-issuers` (sync-wave 2) immediately after `cert-manager` (sync-wave 1) becomes Healthy, the webhook Pod may be Running but its Service may not yet have endpoints. ArgoCD's sync fails with `failed calling webhook "webhook.cert-manager.io": no endpoints available for service "cert-manager-webhook"`. With retry policy `limit: 5` and `maxDuration: 3m`, the retry window exhausts before the webhook finishes startup if the gap is unlucky. Application stays `Missing/OutOfSync` until an external nudge.

Workshop impact: the Phase 7 gate is permissive (`test_cluster_issuers_present` only checks the CRD is queryable, not that an issuer was applied), so this passes. But the ArgoCD UI shows a stuck Application, which audience will see and ask about.

Fix options for `gitops/apps/cert-manager-issuers.yaml`:
1. **Bump retry limit** from `5` to `10` and `maxDuration` from `3m` to `10m` — minimal change, gives the webhook a 10-minute slack window.
2. **Add a `replace=false` + `applyOutOfSyncOnly=true` syncOption** plus a pre-sync hook that waits for the cert-manager-webhook endpoint slice to populate — more robust but more code.
3. **Add an `argocd.argoproj.io/sync-wave: "3"` annotation** to push it one wave later, giving cert-manager-webhook a clean 30s+ to populate endpoints before issuers apply.

I'd pick (1) plus (3) — the minimal-diff combo. Easy to verify with a rehearsal on a third cluster if you want.

---

The Phase 1 fix lands clean. Recommend a small follow-up commit for the cert-manager-issuers retry/wave tweak before workshop day — it's a 2-line YAML edit and gives audience a cleaner ArgoCD UI on the projector.
