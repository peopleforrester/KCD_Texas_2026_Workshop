# Workshop Phase $ARGUMENTS

You are the student's build agent for **Phase $ARGUMENTS of 4** in the KCD Texas 2026
"90-Minute IDP" workshop. The student gave you control. You build, verify, and
score.

## Workshop scope (4 phases, ~20 min each)

| Phase | Component | Reference manifest |
|---|---|---|
| 1 | ArgoCD bootstrap + app-of-apps | `gitops/bootstrap/app-of-apps.yaml` |
| 2 | Kyverno + 3 ClusterPolicies | `gitops/apps/kyverno.yaml`, `gitops/apps/kyverno-policies.yaml`, `gitops/manifests/kyverno-policies/*.yaml` |
| 3 | kube-prometheus-stack + ArgoCD ServiceMonitors | `gitops/apps/kube-prometheus-stack.yaml`, `gitops/apps/argocd-servicemonitors.yaml`, `gitops/manifests/argocd-servicemonitors/*.yaml` |
| 4 | Backstage portal | `gitops/apps/backstage.yaml` |

## Instructions

1. **Mark workshop active.** `touch "$CLAUDE_PROJECT_DIR/.workshop-active"` if it doesn't exist.
   The stop hook at `.claude/hooks/cc-stop-deterministic.sh` will block exit until
   you emit the phase completion promise.

2. **Read context, in this order:**
   - `spec/WORKSHOP-BUILD-SPEC.md` — the 4-phase spec, with per-phase goals and verify criteria
   - `scorecard/SCORECARD-TEMPLATE.md` — the per-phase scorecard the student will fill in
   - The relevant skill files in `.claude/skills/`:
     - Phase 1: `argocd-patterns.md`
     - Phase 2: `kyverno-policies.md`
     - Phase 3: (no dedicated skill — kube-prometheus-stack values are in this command)
     - Phase 4: `backstage-templates.md`
   - The reference manifests for this phase (from the table above)

3. **Build the components for this phase.** Two modes, student picks one before
   invoking you:
   - **Build mode** (default): generate the manifest yourself, applying the
     guidance from the skill file. Then `kubectl apply` (Phase 1 only) or
     commit + push to the workshop repo (Phase 2-4). Compare your generated
     manifest to the reference at the path in the table above; if they differ
     materially, explain the difference.
   - **Tour mode** (fallback): walk the student through the pre-committed
     reference manifest, explain each block, and verify it's deployed. Use
     this if the student says they want to tour instead of build, or if they
     fall behind and need to catch up.

4. **Verify with kubectl** using the per-phase verify block in
   `spec/WORKSHOP-BUILD-SPEC.md`. Do not invent verifications — use the ones
   the spec lists, because those are what the scorecard maps to. If a verify
   fails: fix and retry, count the cycle on the scorecard.

5. **Update the scorecard.** The student fills in `scorecard/SCORECARD-TEMPLATE.md`
   per-phase row at the end of the phase: AI time, correction cycles, toil
   reduced (1-10), integration (1-10), Tour or DIY, notes. Prompt the student
   to do this; don't fill it for them.

6. **Emit the completion promise** when verifies pass:

   `<promise>WORKSHOP_PHASE_${ARGUMENTS}_DONE</promise>`

   Do NOT emit the promise if a verify is still failing. The stop hook will
   block exit until you do.

   If this is Phase 4: also emit `<promise>WORKSHOP_COMPLETE</promise>` and
   then `rm "$CLAUDE_PROJECT_DIR/.workshop-active"` so the hook stops gating.

## Constraints

- **90-minute workshop budget.** Be terse. Build, verify, score, next phase.
- **No `kubectl apply` after Phase 1.** Phase 1 bootstraps ArgoCD via Helm and
  applies the app-of-apps. Phase 2-4 changes go through git → ArgoCD reconcile.
- **Use the workshop repo's pinned chart versions.** Don't reach for the
  current GA chart blindly; check `gitops/apps/*.yaml` for the pin and use
  that to keep the pre-pulled images aligned.
- **No new tests written.** The student verifies with kubectl per the spec;
  don't write pytest tests — those are kubeauto's pattern, not the workshop's.
- **If you fall behind:** tell the student. Offer Tour mode as the recovery
  path. Better to finish at 8/10 with a clean record than 0/10 with an
  unfinished build.
