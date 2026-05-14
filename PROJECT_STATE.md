# PROJECT_STATE.md — KCD Texas 2026 Workshop

**Last updated:** 2026-05-14 (post-extension to full 27-component build)
**Branch:** `staging` (in sync with `main`)
**Workshop date:** 2026-05-15, 10:30 AM CDT

---

## Current state

The workshop has been extended from a 4-phase / 4-component live demo to the **full 7-phase / 27-component build** matching the kubeauto-ai-day reference. Workshop demo still runs as far as Claude gets in 90 minutes; whatever doesn't land in the room, attendees finish from the plane home using this same spec.

**Live validation result on kcd-clust-1:** 45/45 pytest gates passing. 21/22 ArgoCD Applications Healthy (1 Degraded by design — ESO without IRSA, the central scorecard variance point).

**Wall-time on a fresh-ish ArgoCD:**
- Bootstrap to all 21 Applications discovered: ~48 seconds
- Bootstrap to 19 Apps Healthy: ~5 minutes
- Pytest gate sweep: ~4 minutes

Detailed report: `/tmp/workshop-full-build-report.md`.

## Verification method

- **Live cluster:** kcd-clust-1 (us-east-2, EKS 1.32.13)
- **Kubeconfig:** `/tmp/accenture-workshop.kubeconfig` (attendee1 user, cluster-admin via Access Entry)
- **Instructor kubeconfigs:** `/tmp/instructor-kubeconfigs/kcd-clust-{1,2,3}.kubeconfig` (Instructor IAM user; lacks Access Entry on the clusters so only AWS API calls work, not kubectl)
- **Pytest venv:** `/tmp/workshop-venv/` (Python 3.14, pytest 9.0.3)
- **Verified by:** real kubectl + 45 pytest gates + curl probes. Real cluster, no mocks.

## Spec structure

- `spec/BUILD-SPEC.md` — single-paste autonomous prompt for all 7 phases (rewritten for full 27-component scope)
- `spec/phases/phase-0{1..7}-*.md` — per-phase scripts (foundation, gitops, security, observability, portal, integration, hardening)
- `spec/phases/.archive/` — the old 4-phase docs preserved for reference
- `gitops/apps/` — 21 ArgoCD Applications (1 root + 20 children, with `app-of-apps.yaml` in `gitops/bootstrap/`)
- `.claude/skills/` — 6 skill files (added falco-rules, otel-wiring)
- `tests/test_phase_0{1..7}_*.py` — 45 pytest gates across 7 phase files

## Commits ahead of pre-extension main (all on `main` now)

```
88b79e8  Fix Phase 6 integration tests: pick ArgoCD-managed Deployment + accept auth
f75306c  Adjust Phase 2 and Phase 6 test gates for live cluster realities
255f19c  Broaden kyverno CRD ignoreDifferences to cover schema + printer columns
46a2600  Add emptyDir for /var/loki when Loki persistence disabled
33e2fa1  Disable PVC persistence on Loki and Tempo for the workshop cluster
f03852f  Extend workshop spec from 4 phases to 7 (full 27-component build)
0dd5185  Fix three test-bug failures caught during live validation
65498d9  Fix perpetual OutOfSync on kyverno and kyverno-policies Applications
```

## Cluster utilization with full stack deployed

Peak: 19% CPU, 13% memory on the most-loaded node. Workshop stack uses ~5.1 GiB across all namespaces; cluster has ~48 GiB capacity. **t3.xlarge × 3 is wildly over-provisioned. No resource pressure.**

## Next steps (priority order)

| # | Action | Status |
|---|---|---|
| 1 | Review commits on main since the extension | Pending Michael |
| 2 | Install metrics-server on kcd-clust-2 and kcd-clust-3 | **Open**. `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` per cluster. Needs attendee2/3 cred OR Instructor Access Entry added on those clusters. |
| 3 | (Optional) re-validate on kcd-clust-2 to confirm fixes work clean | Optional |
| 4 | (Optional) wire up real IRSA for ESO if you want a 27/27 instead of 26/27 | Out of scope for workshop |
| 5 | Workshop dry-run (the live drive) | Per `spec/PRESENTER-RUNBOOK.md` rehearsal checklist |

## Bugs caught during this extension cycle

All 4 are workshop-day-blocking bugs that the static `dry-run-validate.sh` (63/63) could not catch — only a live-cluster run surfaced them. All 4 fixed on `main`.

1. **Loki PVC stuck Pending** (Accenture cluster has no aws-ebs-csi-driver). `persistence.enabled: false`. (commit `33e2fa1`)
2. **Loki `mkdir /var/loki: read-only file system`** (chart doesn't emptyDir when persistence off). Explicit `extraVolumes`/`extraVolumeMounts`. (commit `46a2600`)
3. **Kyverno CRD chronic drift** (API server reformats descriptions). Broader `ignoreDifferences`; still cosmetically OutOfSync but functionally Healthy. (commit `255f19c`)
4. **Phase 6 drift test on wrong resource** (`argocd-redis` is Helm-owned, not Application-managed). Switched to `kyverno-admission-controller`. (commit `88b79e8`)

## Honest scorecard variance points (what the audience sees)

- **ESO**: Install 8, Integration **2**. Pod runs; ClusterSecretStore Degraded with explicit `InvalidIdentityToken: No OpenIDConnect provider found in your account`. This is the workshop's central "AI installed; AWS prereqs unwired" data point.
- **Backstage**: Install 9, Integration 7, Usability **3**. Pod up; catalog is seed-only; templates aren't wired to a real Git remote. The "platform installed but not shippable" gap = closing slide.
- **cert-manager**: Install 9, Integration 5. ClusterIssuers register but can't actually mint certs without real DNS-01 wiring.
- **Kyverno**: Install 9, Integration 7. Policies enforce; the OutOfSync display is chronic Kyverno + ArgoCD drift on CRD description text. Cosmetic only.

## How to resume

1. Read this file
2. Read `/tmp/workshop-full-build-report.md` for the detailed findings
3. Run `git log staging --not origin/main 2>&1` — both branches should be at `88b79e8` (in sync)
4. Decide whether to install metrics-server on the other two clusters before workshop day
