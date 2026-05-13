# Presenter Run Sheet — 90 minutes, walk-in to walk-out

This is the sequence Michael executes on workshop day. Rough timing is suggested; "how far we get" governs the actual pacing.

---

## T-30 min (10:00 AM) — pre-room

- Plug in laptop, mirror to projector. Left half: terminal. Right half: `scorecard/PRESENTER-SCORECARD.md` open in a Markdown previewer.
- Open `claude` in the cloned workshop repo. Confirm `.claude/skills/*.md` and `.claude/commands/*.md` are loaded (run `/build-phase 1` to dry-run, then close without executing).
- Spin up the pre-recorded Phase 4 video in a separate browser tab, ready to switch to if needed.
- Pull up the closing-slide QR codes in a separate tab: workshop repo, kubeauto reference, agentic-covenants framework, scorecard submission URL.
- Pull up `spec/OPENING-SCRIPT.md` on a second screen (phone, tablet, or other monitor) for reference during the open.

## T-15 min (10:15) — students arrive

- TAs stationed at the door hand connection cards as students enter
- Students sit down, open laptops
- Soft music or screen art on projector ("KCD Texas 2026 — The 90-Minute IDP — Room 3 — Starting at 10:30")
- TAs circulate offering setup help

## T-5 (10:25) — start to settle the room

- Microphone on, audio check
- Take a sip of water
- Verify the projector mirroring still works after the room warmed up

## T+0 (10:30) — open

### Slide 1 — 60-second opener (from `spec/OPENING-SCRIPT.md`)

Read approximately verbatim. The bridge from "I've already built this end-to-end" to "we're not redoing that today" is the rhetorical pivot.

### Slides 2–4 — 5-minute methodology framing (also from `OPENING-SCRIPT.md`)

- Slide 2: spec + skills + test gates (the three artifacts)
- Slide 3: the three scoring dimensions (Install / Integration / Usability)
- Slide 4: today's scope (4 phases, how far we get is how far we get)

### "Open your terminals" pause

> "Open laptops. Connection cards out. Three commands on the back of the card. If `kubectl get nodes` doesn't show three Ready nodes, raise your hand — TAs are circulating. I'll start the build in 60 seconds."

Pause 60–90 seconds. Watch for raised hands. TAs triage in parallel.

## T+6–7 (10:36) — begin Phase 1

Show terminal full-screen briefly:

```bash
$ cat spec/BUILD-SPEC.md
```

Scroll through it on the projector for ~15 seconds while saying:

> "This is the spec. Plain Markdown. About 90 lines. It describes four phases, three scoring dimensions, the test gates, and the chart pins. I'm about to hand it to Claude."

Then:

```bash
$ claude
```

In Claude Code:

```
Read spec/BUILD-SPEC.md and then run /build-phase 1.
```

Watch Claude read the spec, the Phase 1 file, and the ArgoCD skill. Narrate as it does: "Notice it's reading the skill file before it generates anything. That's the spec-driven loop."

Walk through Claude's explanation of the bootstrap. When Claude reaches "I'll generate `~/my-app-of-apps.yaml` now," let it generate. Then diff:

```bash
diff ~/my-app-of-apps.yaml gitops/bootstrap/app-of-apps.yaml
```

Walk through every diff line out loud. Apply the pre-committed bootstrap:

```bash
kubectl apply -f gitops/bootstrap/app-of-apps.yaml
```

Run the test gate commands one by one. As each passes, mark the live scorecard. Phase 1 done; score Install / Integration / Usability with the room watching.

**Say out loud:** "How far we get is how far we get. We landed Phase 1. If we stopped right now, the methodology lesson is complete. Let's keep going."

## T+22 (10:52) — Phase 2

```
Run /build-phase 2.
```

Same pattern: explain → generate → diff → apply gate → score. Phase 2 is two scoring rows (install + policies).

## T+38 (11:08) — Phase 3

```
Run /build-phase 3.
```

Port-forward Grafana on the projector during the gate. The "does the dashboard have real data?" moment is the talk's payoff for this phase — let the room see it land or not.

## T+58 (11:28) — Phase 4 decision

Check the clock. Two paths:

- **>20 minutes left:** Drive Phase 4 live.
- **<10 minutes left:** Switch to the pre-recorded Backstage segment during closing.
- **10–20 minutes left:** Judgment call. If Phase 3 landed cleanly and the room is energized, go live; if Phase 3 was rough and the room is tired, switch to recording.

### Path A (live)

```
Run /build-phase 4.
```

Watch the image config block carefully — that's the trap. If Claude omits the image config in `~/my-backstage.yaml`, name the trap on the diff out loud.

### Path B (recorded)

Switch to the recording tab. Say:

> "We're going to switch to a recording of Phase 4 I made last night, with no audience pressure. Watch what happens — same spec, same Claude, same cluster type, just no time pressure."

Play the recording. As it plays, narrate the failure modes the recording shows — image config, backend system mismatch, whatever happened. Score on the live scorecard.

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

Thank the room. Stay 5 minutes for one-on-one questions. TAs collect student feedback cards if you're doing that.

---

## What can go wrong, in priority order

1. **A student's AWS creds don't work.** TA escalates to the spare cluster. Don't pause the build.
2. **Half the room's `kubectl get nodes` is dark.** Check if you fat-fingered the region in the connection cards (worth a 30s check during setup). TAs help.
3. **My Claude Code locks up mid-build.** Restart `claude`, paste the spec again, resume from the last `<promise>PHASE_N_DONE>` we saw. Don't apologize at length — narrate it as "this is what AI tools look like when they're at the edge of context windows."
4. **A gate fails on stage.** Narrate by name (using the phase spec's Known Failure Modes). The failure is the talk.
5. **The projector mirroring breaks.** TAs have a backup HDMI cable. Worst case, students follow along from the playbook on their own laptops — they have the same Claude, same prompts, same repo.
6. **Time runs short before Phase 4.** Switch to the pre-recorded Backstage segment. Don't try to rush Phase 4 live in 5 minutes.

## Rehearsal checklist (do this once before workshop day)

- [ ] Run `bash scripts/dry-run-validate.sh .` from the repo root. Expect 45/45 pass.
- [ ] Provision a test EKS cluster (NOT the workshop fleet)
- [ ] Configure your local AWS + kubectl to point at it
- [ ] Open `claude` from the cloned repo, paste the spec
- [ ] Run `/build-phase 1` end-to-end. Time it. (Target: 12–15 min for someone who knows the stack.)
- [ ] Run `/build-phase 2`. Time it.
- [ ] Run `/build-phase 3`. Time it. Port-forward Grafana, confirm dashboards populate.
- [ ] Run `/build-phase 4`. **If it fails or takes >25 min, record the run** to use as the Phase 4 fallback video.
- [ ] Practice the opener out loud, three times.
- [ ] Practice the closing script out loud, twice.
- [ ] Confirm the projector mirroring works with your typical terminal font sizes (audience needs to read it from the back of the room).

If anything in rehearsal surfaces a spec/skill bug, edit the relevant Markdown file. Re-run `dry-run-validate.sh`. Commit.
