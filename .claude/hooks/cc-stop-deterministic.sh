#!/usr/bin/env bash
# ABOUTME: Workshop stop hook -- blocks Claude Code from exiting a /workshop-phase
# ABOUTME: until the phase has emitted a <promise>WORKSHOP_PHASE_N_DONE</promise> tag.
#
# Inactive unless a marker file ($CLAUDE_PROJECT_DIR/.workshop-active) exists.
# The /workshop-phase command creates this marker; the phase's success path
# removes it.  Outside of an active phase, this hook approves all stops.

OUTPUT=$(cat -)

if [ ! -f "$CLAUDE_PROJECT_DIR/.workshop-active" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Per-phase completion promises
if echo "$OUTPUT" | grep -qE "<promise>WORKSHOP_PHASE_[1-4]_DONE</promise>"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Full-workshop completion
if echo "$OUTPUT" | grep -q "<promise>WORKSHOP_COMPLETE</promise>"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Block exit -- keep iterating
echo '{"decision": "block", "reason": "Phase not complete.  Continue working on the current /workshop-phase: write/update the manifest, kubectl apply or push to git, verify with the phase verify commands, update the scorecard, then emit <promise>WORKSHOP_PHASE_N_DONE</promise>."}'
exit 0
