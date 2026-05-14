# Presenter Run Sheet — 90 minutes, walk-in to walk-out

This is the sequence Michael executes on workshop day. Rough timing is suggested; "how far we get" governs the actual pacing.

---

## T-30 min (10:00 AM) — pre-room

- Plug in laptop, mirror to projector. Left half: terminal. Right half: `scorecard/PRESENTER-SCORECARD.md` open in a Markdown previewer.
- Open `claude` in the cloned workshop repo. Confirm `.claude/skills/*.md` and `.claude/commands/*.md` are loaded (run `/build-phase 1` to dry-run, then close without executing).
- Spin up the pre-recorded Phase 4 video in a separate browser tab, ready to switch to if needed.
- Pull up the closing-slide QR codes in a separate tab: workshop repo, kubeauto reference, agentic-covenants framework, scorecard submission URL.
- Pull up `spec/OPENING-SCRIPT.md` on a second screen (phone, tablet, or other monitor) for reference during the open.

## Credential distribution

**Direction (for the PowerPoint, not yet spec'd):** QR code at the door → self-service landing page that hands each student a unique pre-provisioned cluster credential. Single source of truth, no manual handoff, no clipboard tracking. The detailed design (landing page architecture, credential pool management, claim-tracking) is a separate deliverable; for now, the runbook assumes the QR-and-landing-page flow exists by workshop day.

Until that's built, fallback is printed numbered cards in a stack at the door. Same content either way: cluster name, region, AWS keys, repo URL, three setup commands.

## T-15 min (10:15) — students arrive

- Slide on projector: large QR code + "Scan to claim your cluster" + "Doors close 10:28, build starts 10:30"
- Students scan, land on the page, get their unique cluster credential, copy it into their terminal
- You are at the front of the room, not at the door — the QR code is doing the work

## T-5 (10:25) — start to settle the room

- Microphone on, audio check
- Take a sip of water
- Verify the projector mirroring still works after the room warmed up
- Check the landing page's claim counter: if it's reading "53 claimed of 60 available" at 10:25, you can start on time. If it's reading "31 of 60," people are still walking in and you'll want to budget extra setup time during the opener.

## T+0 (10:30) — open

### Slide 1 — 60-second opener (from `spec/OPENING-SCRIPT.md`)

Read approximately verbatim. The bridge from "I've already built this end-to-end" to "we're not redoing that today" is the rhetorical pivot.

### Slides 2–4 — 5-minute methodology framing (also from `OPENING-SCRIPT.md`)

- Slide 2: spec + skills + test gates (the three artifacts)
- Slide 3: the three scoring dimensions (Install / Integration / Usability)
- Slide 4: today's scope (7 phases / 27 components, how far we get is how far we get)

### "Open your terminals" pause

> "Open laptops. Three commands from your landing-page card. Get to `kubectl get nodes` showing three Ready nodes. **There are no TAs today — it's just me — so the setup window is the time to surface problems.** If your terminal isn't green in five minutes, raise your hand and I'll come over before we start Phase 1. I'd rather start two minutes late with everyone connected than on time with a third of the room behind."

Pause 3–5 minutes for setup. Be visible — walk between the rows once during the pause, eyeballing screens. People who are stuck will signal even without raising their hands if they see you nearby.

**You alone with 60 students is the operational reality.** Triage during this window is the most important thing you do in the first 15 minutes — once Phase 1 starts, you're driving Claude on the projector and can't simultaneously help individuals. Be honest with the room about this up front.

## T+6–7 (10:36) — begin the autonomous build

Show terminal full-screen briefly:

```bash
$ cat spec/BUILD-SPEC.md
```

Scroll through it on the projector for ~15 seconds while saying:

> "This is the spec. Plain Markdown. About 100 lines. It tells Claude how to execute the build autonomously — read each phase's reference, run the pytest test gate, emit a promise when all tests pass, pause for me to score. Single paste, autonomous run."

Then:

```bash
$ claude
```

In Claude Code, paste the autonomous-execution prompt from `spec/BUILD-SPEC.md` (the block under "How Claude executes this spec"). One paste, the whole workshop.

Claude will:
1. Read Phase 1's reference + the ArgoCD skill
2. Generate `~/my-app-of-apps.yaml`
3. Diff against `gitops/bootstrap/app-of-apps.yaml` — walk you through the diff
4. Apply the pre-committed bootstrap
5. Run `pytest tests/test_phase_01_foundation.py -v`
6. When all tests pass: output `<promise>PHASE_1_DONE</promise>` and pause

Score Phase 1 on the live scorecard with the room watching. Say "continue" — Claude moves to Phase 2 autonomously. Repeat for Phases 2 through 7.

**You are the conductor, not the operator.** Claude is doing spec-driven dev live; you narrate the failures by name when they happen, score after each promise, and decide when to stop.

## T+22+ — autonomous phases continue

Same loop. Each phase ends with a promise; you score; you say "continue." Don't paste anything Claude can do from the spec — that defeats the demonstration.

If a phase emits `<promise>PHASE_N_FAILED</promise>`: that's data, not catastrophe. Narrate why the tests failed using the phase spec's Known failure modes. Score Install based on what Claude got right, Integration/Usability based on what the gate revealed.

Check the clock when Claude reaches the Phase 3 promise. Two paths:

- **>20 minutes left:** Let the autonomous loop continue into Phase 4. Say "continue."
- **<10 minutes left:** Tell Claude `stop and emit ALL_PHASES_COMPLETE`. Switch to the pre-recorded Backstage segment during closing.
- **10–20 minutes left:** Judgment call. If Phase 3 landed cleanly and the room is energized, let Claude continue; if Phase 3 was rough and the room is tired, switch to recording.

### Path A — let Claude continue into Phase 4

Say "continue." Claude reads the Phase 4 reference and the Backstage skill, generates `~/my-backstage.yaml`, diffs against ground truth. Watch the diff carefully — `backstage.image.repository` and `backstage.image.tag` are the no-default-image trap. If Claude's generated manifest is missing them, that's the moment. Name it.

When the pytest gate runs, watch `test_backstage_pod_running` specifically — that's the one that catches the image trap. If it fails, that failure (and the logs surfaced in the pytest output) is the talk's payoff.

### Path B — pre-recorded fallback

Tell Claude `stop and emit ALL_PHASES_COMPLETE`. Switch to the Phase 4 recording tab. Say:

> "We didn't get to Phase 4 live today. Here's the recording I made last night, no audience pressure, same spec, same Claude. Watch what AI did."

Play the recording. Narrate the failure modes it shows. Score on the live scorecard with the numbers from the recording.

## T+80–85 (11:50) — wrap-up

### Closing script (from `spec/OPENING-SCRIPT.md`)

Point at the live scorecard. Read the totals. Make the "Install ≫ Integration ≫ Usability" pattern visible. Connect it to the kubeauto reference scorecard.

### Take-home moment

> "The platform gets destroyed in an hour. The repo is public. What goes home is your scorecard. The methodology — spec, skills, gates, scoring — goes home with you. Apply it to whatever you're building Monday."

### QR codes on the closing slide

- Workshop repo: `github.com/peopleforrester/KCD_Texas_2026_Workshop`
- Reference build: `github.com/peopleforrester/kubeauto-ai-day`
- Agentic Covenants framework: `github.com/peopleforrester/agentic-covenants`
- Optional scorecard submission: `<form URL or fork instruction>`

## T+90 (12:00) — done

Thank the room. Stay 5 minutes for one-on-one questions. If you're collecting student scorecards for the follow-on talk, have a labeled bin or designated email address visible on the closing slide so opt-in submissions land somewhere you'll actually find them.

---

## What can go wrong, in priority order

You're alone with 60 students. Triage decisions are blunt: keep the room moving, accept that 1–2 individuals will be behind, do not pause Phase 1+ to fix one cluster.

1. **A student's credentials don't work / `kubectl get nodes` fails.** During the setup window only: walk over, look at the screen, common fix is usually region typo or stale `~/.aws/credentials`. **If it's not a 30-second fix, hand them a spare cluster's credentials from your pocket and move on.** Pre-provision 5–10 spare clusters expressly for this. After Phase 1 starts, students with broken setups become observers, not participants — they still see the methodology, they just can't run alongside.
2. **My Claude Code locks up mid-build.** Restart `claude`, paste the spec again, resume from the last `<promise>PHASE_N_DONE>` we saw. Don't apologize at length — narrate it as "this is what AI tools look like when they're at the edge of context windows."
3. **A test gate fails on stage.** Narrate by name using the phase spec's Known Failure Modes. The failure is the talk.
4. **Setup pause runs long.** If at T+8 minutes (10:38) you've still got more than ~5 students dark, *don't push to T+15*. Start Phase 1 anyway. Dark students keep watching, score on the connection-card scorecard based on what they see Claude do on the projector. Honest framing: "If your setup didn't land, you're in observer mode for the build — still take notes, still score what you see."
5. **The projector mirroring breaks.** Backup HDMI cable in your bag. Worst case, students follow along from the playbook on their own laptops — they have the same Claude, same prompts, same repo.
6. **The QR landing page is down at T-15.** Fall back to printed numbered cards (which you should also have in your bag, even when the QR flow is "working"). This is your insurance policy and the reason the cards-direction is in this runbook even though the QR flow is the plan.
7. **Time runs short before Phase 4.** Switch to the pre-recorded Backstage segment. Don't try to rush Phase 4 live in 5 minutes.

The single highest-leverage thing to do for "Michael alone" mode: **pre-provision spare clusters and have spare credentials physically with you.** The cost is 5–10 unused EKS clusters for a day. The value is being able to swap a broken cluster in 30 seconds instead of debugging it in 5 minutes during a workshop you're also running.

## Rehearsal checklist (do this once before workshop day)

- [ ] Run `bash scripts/dry-run-validate.sh .` from the repo root. Expect 45/45 pass.
- [ ] Provision a test EKS cluster (NOT the workshop fleet)
- [ ] Configure your local AWS + kubectl to point at it
- [ ] Open `claude` from the cloned repo, paste the spec
- [ ] Run `/build-phase 1` end-to-end. Time it. (Target: 12–15 min for someone who knows the stack.)
- [ ] Run `/build-phase 2`. Time it.
- [ ] Run `/build-phase 3`. Time it. Port-forward Grafana, confirm dashboards populate.
- [ ] Run `/build-phase 4`. **If it fails or takes >25 min, record the run** to use as the Phase 4 fallback video. **This recording is non-optional given you're alone in the room — it's your insurance against running long.**
- [ ] Practice the opener out loud, three times. Especially the "there are no TAs today, just me" line — it's a real constraint and the room needs to hear it.
- [ ] Practice the closing script out loud, twice.
- [ ] Confirm the projector mirroring works with your typical terminal font sizes (audience needs to read it from the back of the room).
- [ ] Print ~70 numbered credential cards as a fallback even if the QR landing page is ready. Carry them in your bag. They cost nothing and they're the insurance policy if the landing page misbehaves.
- [ ] Pre-provision 5–10 spare clusters with their credentials on extra cards. Keep those cards in your pocket — not in a folder, not in a bag, in your pocket. Walking-distance access matters when you have 60 seconds to swap a broken cluster.

If anything in rehearsal surfaces a spec/skill bug, edit the relevant Markdown file. Re-run `dry-run-validate.sh`. Commit.
