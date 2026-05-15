#!/usr/bin/env bash
# ABOUTME: Workshop stop hook -- blocks Claude Code from exiting a /build-phase
# ABOUTME: until the phase has emitted a <promise>PHASE_N_DONE</promise> tag.
#
# ── STATUS: CURRENTLY INACTIVE ─────────────────────────────────────────────
# This hook was the enforcement mechanism for the older per-phase
# /build-phase workflow.  The current primary flow is single-paste
# autonomous execution from spec/BUILD-SPEC.md (see CLAUDE.md and the
# "Why single-paste replaced per-phase" notes in the runbook).
#
# Nothing in the repo creates the $CLAUDE_PROJECT_DIR/.build-active marker
# anymore, which means the first guard below short-circuits to "approve"
# on every invocation.  The PHASE_[1-7]_DONE / ALL_PHASES_COMPLETE checks
# below are dead code today.  They are preserved -- and kept consistent
# with the current 7-phase scope -- so that if /build-phase is ever
# reactivated (i.e., something starts touching .build-active again) the
# hook is correct on first use rather than requiring a separate cleanup.
# ───────────────────────────────────────────────────────────────────────────
#
# When active: the /build-phase command creates the marker; the phase's
# success path removes it.  Outside of an active phase, this hook
# approves all stops.

OUTPUT=$(cat -)

if [ ! -f "$CLAUDE_PROJECT_DIR/.build-active" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Per-phase completion promise (PHASE_1_DONE through PHASE_7_DONE)
if echo "$OUTPUT" | grep -qE "<promise>PHASE_[1-7]_DONE</promise>"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Full-workshop completion -- spec/BUILD-SPEC.md emits ALL_PHASES_COMPLETE
# (not ALL_PHASES_DONE), so the tokens here match what the autonomous
# executor would produce if /build-phase were ever wired into it.
if echo "$OUTPUT" | grep -q "<promise>ALL_PHASES_COMPLETE</promise>"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Block exit -- keep iterating
echo '{"decision": "block", "reason": "Phase not complete.  Continue the current /build-phase: read the skill, generate the manifest to ~/my-<component>.yaml, diff against gitops/apps/<component>.yaml, walk through the gate commands, and emit <promise>PHASE_N_DONE</promise> when the gate passes."}'
exit 0
