#!/bin/bash
# Work queue monitor hook logic
# Called by hook-framework.sh

# Extract command
command=$(get_command)

# Check if a work signal file exists (created by handoff scripts)
if [ -f /tmp/persona-work-ready ]; then
    NEXT_PERSONA=$(cat /tmp/persona-work-ready)
    rm -f /tmp/persona-work-ready
    
    # Log that we detected a handoff
    log_hook_event "WORK:QUEUE" "Detected work ready for $NEXT_PERSONA"
    
    # Prepare the next work item
    es-work-tracker.sh prepare "$NEXT_PERSONA"
fi

# Also check if command indicates work completion
if [[ "$command" =~ "WORK:COMPLETED" ]]; then
    # Extract persona from the command
    if [[ "$command" =~ es-journal-log.*WORK:COMPLETED.*([A-Z]+): ]]; then
        PERSONA="${BASH_REMATCH[1]}"
        
        # Check if more work exists for this persona
        PENDING_COUNT=$(get_pending_count "$PERSONA")
        
        if [ "$PENDING_COUNT" -gt 0 ]; then
            # Prepare next work item
            es-work-tracker.sh prepare "$PERSONA"
        else
            # Check if this persona should hand off
            log_hook_event "WORK:QUEUE" "No more work for $PERSONA, checking for handoff"
        fi
    fi
fi
