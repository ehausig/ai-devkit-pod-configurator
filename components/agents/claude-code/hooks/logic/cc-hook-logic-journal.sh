#!/bin/bash
# Journal hook logic for Stop events
# Called by hook-framework.sh

# Check if this is a stop hook that's already active to prevent loops
stop_hook_active=$(extract_json_field "$JSON_INPUT" '.stop_hook_active' 'false')

if [ "$stop_hook_active" = "true" ]; then
    # Don't create recursive journal entries or continuations
    exit 0
fi

# Log the session completion first
log_hook_event "INFO" "Session $SESSION_ID completed - Claude Code session completed"

# Check for pending persona work
if [ -f /tmp/persona-work-ready ]; then
    NEXT_PERSONA=$(cat /tmp/persona-work-ready 2>/dev/null)
    
    if [ -n "$NEXT_PERSONA" ]; then
        # Log the automatic continuation
        log_hook_event "AUTOMATION:CONTINUE" "Automatically continuing with $NEXT_PERSONA persona"
        
        # Clean up the signal file
        rm -f /tmp/persona-work-ready
        
        # Force continuation with JSON response and exit code 2
        cat << EOF
{
    "decision": "block",
    "reason": "Continuing automated workflow with $NEXT_PERSONA persona. Please run: persona-$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh"
}
EOF
        exit 2
    fi
fi

# Fallback: Check if any persona has pending work items
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    PENDING_COUNT=$(es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l || echo "0")
    
    if [ "$PENDING_COUNT" -gt 0 ]; then
        # Log the discovery of pending work
        log_hook_event "AUTOMATION:DETECTED" "Found $PENDING_COUNT pending work items for $persona"
        
        # Signal this persona for continuation
        echo "$persona" > /tmp/persona-work-ready
        
        # Force continuation with JSON response and exit code 2
        cat << EOF
{
    "decision": "block",
    "reason": "Detected $PENDING_COUNT pending work items for $persona. Please run: persona-$(echo $persona | tr '[:upper:]' '[:lower:]')-init.sh"
}
EOF
        exit 2
    fi
done

# No pending work found - allow normal session completion
# Check if we should start a new cycle
RECENT_MERGER_HANDOFF=$(es-journal-query.sh recent-context MERGER 5 2>/dev/null | grep -c "HANDOFF:COMPLETED" || echo "0")

if [ "$RECENT_MERGER_HANDOFF" -gt 0 ]; then
    log_hook_event "AUTOMATION:CYCLE_COMPLETE" "Development cycle completed successfully"
fi

# Exit normally (allow session to end)
exit 0
