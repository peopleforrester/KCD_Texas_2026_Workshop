#!/usr/bin/env bash
# ABOUTME: Workshop stop hook -- blocks Claude Code from exiting a /build-phase
# ABOUTME: until the phase has emitted a <promise>PHASE_N_DONE</promise> tag.
#
# Inactive unless a marker file ($CLAUDE_PROJECT_DIR/.build-active) exists.
# The /build-phase command creates this marker; the phase's success path
# removes it.  Outside of an active phase, this hook approves all stops.

OUTPUT=$(cat -)

if [ ! -f "$CLAUDE_PROJECT_DIR/.build-active" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Per-phase completion promise (PHASE_1_DONE through PHASE_4_DONE)
if echo "$OUTPUT" | grep -qE "<promise>PHASE_[1-4]_DONE</promise>"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Full-workshop completion
if echo "$OUTPUT" | grep -q "<promise>ALL_PHASES_DONE</promise>"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Block exit -- keep iterating
echo '{"decision": "block", "reason": "Phase not complete.  Continue the current /build-phase: read the skill, generate the manifest to ~/my-<component>.yaml, diff against gitops/apps/<component>.yaml, walk through the gate commands, and emit <promise>PHASE_N_DONE</promise> when the gate passes."}'
exit 0
