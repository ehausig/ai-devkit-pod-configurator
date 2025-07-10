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
log_hook_event "DEBUG" "Stop hook executing - checking for handoff signals"

# Debug: Log what files exist and their contents
if [ -f /tmp/force-session-end ]; then
    FORCE_CONTENT=$(cat /tmp/force-session-end 2>/dev/null)
    log_hook_event "DEBUG" "Found force-session-end file with content: '$FORCE_CONTENT'"
else
    log_hook_event "DEBUG" "No force-session-end file found"
fi

if [ -f /tmp/persona-work-ready ]; then
    WORK_CONTENT=$(cat /tmp/persona-work-ready 2>/dev/null)
    log_hook_event "DEBUG" "Found persona-work-ready file with content: '$WORK_CONTENT'"
else
    log_hook_event "DEBUG" "No persona-work-ready file found"
fi

# List all temp files for debugging
TEMP_FILES=$(ls -la /tmp/*persona* /tmp/*force* /tmp/*work* 2>/dev/null || echo "No matching temp files")
log_hook_event "DEBUG" "Temp files: $TEMP_FILES"

# Priority 1: Check for forced session end (from handoff)
if [ -f /tmp/force-session-end ]; then
    NEXT_PERSONA=$(cat /tmp/force-session-end 2>/dev/null)
    
    if [ -n "$NEXT_PERSONA" ]; then
        # Log the forced continuation
        log_hook_event "AUTOMATION:FORCED_CONTINUE" "Forced continuation with $NEXT_PERSONA persona after handoff"
        
        # Clean up the force file
        rm -f /tmp/force-session-end
        
        # Also clean up work-ready file if it exists
        rm -f /tmp/persona-work-ready
        
        # CRITICAL: For Stop hooks with exit code 2, JSON must go to stderr
        # Use the exact format that works for Stop hooks
        echo "{\"decision\": \"block\", \"reason\": \"Automatically continuing with $NEXT_PERSONA persona after handoff. Please run: persona-$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh\"}" >&2
        exit 2
    fi
fi

# Priority 2: Check for pending persona work signal
if [ -f /tmp/persona-work-ready ]; then
    NEXT_PERSONA=$(cat /tmp/persona-work-ready 2>/dev/null)
    
    if [ -n "$NEXT_PERSONA" ]; then
        # Log the automatic continuation
        log_hook_event "AUTOMATION:CONTINUE" "Automatically continuing with $NEXT_PERSONA persona"
        
        # Clean up the signal file
        rm -f /tmp/persona-work-ready
        
        # CRITICAL: For Stop hooks with exit code 2, JSON must go to stderr
        echo "{\"decision\": \"block\", \"reason\": \"Continuing automated workflow with $NEXT_PERSONA persona. Please run: persona-$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh\"}" >&2
        exit 2
    fi
fi

# Priority 3: Check for pending work items across all personas (deterministic)
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    PENDING_COUNT=$(es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l || echo "0")
    
    if [ "$PENDING_COUNT" -gt 0 ]; then
        # Log the discovery of pending work
        log_hook_event "AUTOMATION:DETECTED" "Found $PENDING_COUNT pending work items for $persona"
        
        # Signal this persona for continuation
        echo "$persona" > /tmp/persona-work-ready
        
        # CRITICAL: For Stop hooks with exit code 2, JSON must go to stderr
        echo "{\"decision\": \"block\", \"reason\": \"Detected $PENDING_COUNT pending work items for $persona. Please run: persona-$(echo $persona | tr '[:upper:]' '[:lower:]')-init.sh\"}" >&2
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
