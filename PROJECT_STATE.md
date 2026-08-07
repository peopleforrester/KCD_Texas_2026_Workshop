# Project State: KCD-Texas-2026

Phase: 3.1 Stage
Approved: pending

## Lifecycle
- [x] 1.1 Research
- [x] 1.2 Plan
- [ ] 1.3 Approve
- [ ] 2.1 Test
- [x] 2.2 Implement
- [x] 2.3 Verify
- [x] 3.1 Stage  ← you are here
- [ ] 3.2 Confirm CI
- [ ] 3.3 Promote

## Contracts

None sealed. Post-event documentation work, taken under the trivial-work escape hatch rather than a PRD.

## Current Plan

**The workshop shipped.** Delivered at KCD Texas 2026 on 2026-05-15, Room 3, 10:30 CDT. Infrastructure is fully torn down. The repository is now a public portfolio artifact, not a live workshop staging area.

Current work is presentation of the finished thing, not changes to the build:

- README rewritten results-forward, past tense, leading with the Install 9.7 / Integration 8.1 / Usability 7.1 curve and disclosing that the scores were reconstructed post-hoc.
- Deck converted to PDF at `slides/` so it renders in a browser. The `.pptx` stays at the root as the source.
- Hero image generated for the README and LinkedIn (`assets/hero.png`, plus `assets/hero-alt-stack.png` as an alternate). Three variants also copied to Megumi at `C:\Users\itama\Downloads\LinkedIn Images for Resume`.
- `docs/LINKEDIN-SUMMARY.md` carries the featured-item blurb and post variants.
- `transcripts/` gitignored. It held a routed private call transcript sitting untracked inside a public repo.
- Roadmap and retrospective converted to GitHub issues so another repo can pick them up.

## Delivered outcome (2026-05-15)

| | Install | Integration | Usability |
|---|---:|---:|---:|
| Average across 7 phases | 9.7 | 8.1 | 7.1 |

- ~21 minutes of AI time against a ~10 hour unpressured overnight baseline for the same spec.
- EKS path: 12 pool slots dispensed, 7 clusters with workshop activity, 6 at full 32-Application fan-out.
- KodeKloud path unmeasurable from server-side telemetry. Recorded as a known gap, not smoothed over.
- Zero attendee scorecards returned. The fork-edit-PR loop was too much friction inside 90 minutes on ephemeral clusters.

Canonical record: `scorecard/results/presenter-2026-05-15.md`.

## Open issues (filed 2026-08-07)

On [KCD_Texas_2026_Workshop](https://github.com/peopleforrester/KCD_Texas_2026_Workshop/issues), indexed by epic #14:

- #1 to #4: retrospective followups (capture-at-source scorecards, live `/score-component` write failure, KodeKloud telemetry, EKS metrics-server SG gap).
- #5 to #13: roadmap phases 8 through 16 (agent gateway, SPIFFE, Dex, OpenBao, LLM inference, self-service, supply chain, service mesh, progressive delivery).

On [llm-coding-workflow](https://github.com/peopleforrester/llm-coding-workflow/issues): #27, #28, #29 to codify a `portfolio-repo` skill, its rubric, and a deterministic readiness checker, using this repo as the reference output.

## Branch & Tests

- Branch: `staging`
- Working tree: see `git status`
- Gates: 49 pytest functions across 7 phase files. Cluster-dependent, so unrunnable now that the fleet is torn down. `scripts/dry-run-validate.sh` is the cluster-free check and is what CI runs.
- Note: repo docs previously claimed 47 gates. The tree has 49. Badge and README now cite the measured number.

## Phase History

- 2026-05-14 pre-event live validation on kcd-clust-1, all gates green, 32/33 Applications Healthy
- 2026-05-15 workshop delivered; canonical scorecard captured post-close
- 2026-05-16 next-gen roadmap (phases 8-16) committed
- 2026-08-07 3.1 repository converted to a portfolio artifact; roadmap and retrospective filed as issues
