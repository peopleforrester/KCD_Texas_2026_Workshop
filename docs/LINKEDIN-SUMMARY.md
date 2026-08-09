<!-- ABOUTME: Ready-to-paste LinkedIn copy for the KCD Texas 2026 workshop repo. -->
<!-- ABOUTME: Featured-item blurb plus a longer post variant; numbers cite scorecard/results/presenter-2026-05-15.md. -->

# LinkedIn copy for this repo

Every number below comes from [`scorecard/results/presenter-2026-05-15.md`](../scorecard/results/presenter-2026-05-15.md). Do not round them upward.

Suggested image: `assets/linkedin-hero.png`. It is the hero illustration with the results and a real
headshot composited on, sized 1200x627 for a LinkedIn link card. `assets/linkedin-hero-clown.png` is
the same layout over the Clown Native Computing banner if the post wants the lighter tone.

In the LinkedIn images folder the current files for this project are
`KCD-Texas-hero.png` (the post image) and `KCD-Texas-social-card.jpg` (1280x640,
for the GitHub social preview card). Rebuild either with
`python3 scripts/build-linkedin-hero.py` after dropping a newer headshot in beside it.

---

## Featured item

**Title:** The 90-Minute IDP: what AI actually leaves behind

**Description:**
A live workshop at KCD Texas 2026 where the room built a 27-component Internal Developer Platform on real EKS clusters with Claude Code, then scored it on three dimensions instead of one. Install 9.7, Integration 8.1, Usability 7.1. The whole finding is the gap between those numbers.

**Link:** https://github.com/peopleforrester/KCD_Texas_2026_Workshop

---

## Post variant

At KCD Texas in May I ran a 90-minute workshop that did not argue about whether AI can build a platform. It just built one, live, in front of the room, and scored it.

Seven phases. 27 CNCF components. 62 EKS clusters provisioned so the audience could follow along on their own infrastructure rather than watch mine.

The trick was refusing to score it as one number. Every component got three:

Install: did it come up Healthy first try?
Integration: does it work with everything else, end to end?
Usability: could a developer on your team drive this Monday morning?

Install 9.7. Integration 8.1. Usability 7.1.

That curve is the finding. AI installed almost everything perfectly. It integrated most things. It left usability roughly where it found it.

The single most useful number in the whole workshop was Backstage scoring 3 out of 10 on usability. The pod was Healthy. The catalog was seed-only and the templates were not wired to a real Git remote. Installed, and not shippable. That is not an AI failure. That is the shape of the work that does not disappear.

Same story for External Secrets Operator at 2 out of 10 on integration: the operator ran fine, and the AWS IRSA prerequisite was never wired, because wiring it was never the component's job.

For comparison, the same spec run overnight without an audience took about ten hours. The live run took about 21 minutes of AI time, and scored higher on Install, because by then the spec, the skill files and the test gates had been hardened against a real cluster.

Everything is public and MIT licensed: the spec, the skill files that stop the model reproducing two-year-old Helm patterns, the 49 pytest gates, the Terraform, and the honest scorecard including where the capture method was imperfect.

https://github.com/peopleforrester/KCD_Texas_2026_Workshop

---

## Short variant

Built a 27-component Internal Developer Platform live on stage at KCD Texas with Claude Code, in front of an audience running the same spec on their own EKS clusters.

Scored every component on three dimensions rather than one: Install 9.7, Integration 8.1, Usability 7.1.

The gap between those numbers is the finding. AI installs almost perfectly and leaves usability where it found it. Backstage came up Healthy and scored 3 out of 10 on usability, because installed and shippable are different words.

Spec, skill files, 49 pytest gates, Terraform and the honest scorecard, all MIT:
https://github.com/peopleforrester/KCD_Texas_2026_Workshop
