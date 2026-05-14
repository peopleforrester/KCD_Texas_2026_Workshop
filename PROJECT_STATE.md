# PROJECT_STATE.md — KCD Texas 2026 Workshop

**Last updated:** 2026-05-14 (end-to-end validation on Accenture cluster)
**Branch:** `staging` (2 commits ahead of `origin/main`)
**Workshop date:** 2026-05-15, 10:30 AM CDT

---

## Current state

Full end-to-end walkthrough of `spec/BUILD-SPEC.md` executed on Accenture-provisioned `kcd-clust-1` as user `attendee1`. **21 of 22 pytest assertions pass.** The remaining failure is a known cosmetic drift issue with a fix already on `staging` awaiting fast-forward to `main`.

Detailed write-up: `/tmp/workshop-validation-report.md`.

## Verification method

- **Live cluster:** kcd-clust-1 (us-east-2, EKS 1.32.13)
- **Kubeconfig:** `/tmp/accenture-workshop.kubeconfig` (attendee1 user, cluster-admin via Access Entry)
- **Instructor kubeconfigs:** `/tmp/instructor-kubeconfigs/kcd-clust-{1,2,3}.kubeconfig` (Instructor IAM user) — note: Instructor lacks Access Entries on the clusters, so these only work for AWS-EKS API calls, not in-cluster kubectl.
- **Pytest venv:** `/tmp/workshop-venv/` (Python 3.14, pytest 9.0.3)
- **Verified by:** kubectl + pytest gates + curl probes against port-forwarded Backstage. Real cluster, no mocks.
- **NOT verified:** kcd-clust-2 and kcd-clust-3 — same Terraform-generated topology, but neither has metrics-server installed yet.

## Next steps (priority order)

| # | Action | Who | Risk if skipped |
|---|---|---|---|
| 1 | Review staging commits `65498d9` (kyverno OutOfSync fix) and `0dd5185` (test-bug fixes) | Michael | None — read-only |
| 2 | Fast-forward `main` to `staging`: `git checkout main && git merge --ff-only staging && git push origin main` | Michael | If skipped, workshop demo shows OutOfSync on projector + Phase 1 gate fails |
| 3 | After main is updated, force a hard refresh on the live `app-of-apps` Application (or just wait 30 s for next reconciliation): drift indicators clear, Phase 1 gate passes 22/22 | Michael or Claude | Tests will fail until main is updated |
| 4 | Install metrics-server on kcd-clust-2 and kcd-clust-3 | Michael (instructor profile needs Access Entry on those 2 clusters first, OR run as attendee2/attendee3) | Students typing `kubectl top` get a 503; not blocking workshop content |
| 5 | (Optional) Run the validation again on kcd-clust-2 to confirm fixes work clean | Michael | None — extra confidence only |

## Bugs found during validation

All four are workshop-day-blocking. All four are fixed on `staging` branch but **not yet on `main`**.

1. **Phase 1 OutOfSync** (commit `65498d9`) — Kyverno admission webhook + apiserver inject default fields not present in git; ArgoCD shows perpetual OutOfSync. Fixed with scoped `ignoreDifferences` blocks.
2. **conftest.py `Succeeded` pods rejected** (commit `0dd5185`) — Job pods finishing in Succeeded triggered false negatives.
3. **`kubectl run --rm --dry-run=server` invalid combo** (commit `0dd5185`) — Phase 2 admission test was rejected by kubectl client-side, not by the policy. Couldn't actually verify Kyverno enforcement.
4. **Stale Backstage image expectation** (commit `0dd5185`) — Phase 4 test still asserted the deprecated `roadiehq/community-backstage-image:1.50.4` even though everything else in the workshop migrated to `ghcr.io/backstage/backstage:1.30.2` weeks ago.

## Cluster resource verdict

Workshop stack memory: ~2.2 GiB across all namespaces. t3.xlarge × 3 cluster: ~45 GiB capacity. **~5% headroom usage. The clusters are wildly over-provisioned for this workshop.** Resource pressure will not be a workshop concern.

## State of the Accenture cluster fleet

| Cluster | K8s ver | Attendee user | metrics-server | Access Entries verified |
|---|---|---|---|---|
| kcd-clust-1 | 1.32 (extended support) | attendee1 | ✅ v0.8.1 installed | ✅ attendee1 + shawnmeunier |
| kcd-clust-2 | 1.32 (extended support) | attendee2 | ❌ not installed | ✅ attendee2 + shawnmeunier (added by previous session) |
| kcd-clust-3 | 1.32 (extended support) | attendee3 | ❌ not installed | ✅ attendee3 + shawnmeunier (added by previous session) |

Extended-support surcharge: $0.50/hr per cluster on top of the $0.10/hr control plane. For the workshop's 3-hour window: ~$5/clusters/hr × 3 hr × 3 clusters = trivial extra cost. Stay on 1.32.

## How to resume

1. Read this file
2. Read `/tmp/workshop-validation-report.md` for the detailed findings
3. Run `git status` and `git log staging --not main` to see what's pending
4. Decide on the fast-forward; everything else flows from that
