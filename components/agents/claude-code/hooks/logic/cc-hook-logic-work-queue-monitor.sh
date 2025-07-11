#!/bin/bash
# Work queue monitor hook logic - SIMPLIFIED to remove handoff logic
# Called by hook-framework.sh
# Focus: Work completion monitoring and preparation only

# Extract command
command=$(get_command)

# REMOVED: All handoff detection logic - now handled by journal hook
# REMOVED: All file signaling logic (/tmp/persona-work-ready, /tmp/force-session-end)
# FOCUS: Work completion detection and next work preparation only

# Priority 1: Check if command indicates work completion
if [[ "$command" =~ "WORK:COMPLETED" ]]; then
    # Use centralized journal query instead of regex parsing
    PERSONA=$(es-journal-query.sh work-completed-persona)
    
    if [ -n "$PERSONA" ] && [[ "$PERSONA" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
        log_hook_event "WORK:QUEUE" "Detected work completion for $PERSONA"
        
        # Check if more work exists for this persona
        PENDING_COUNT=$(es-journal-query.sh pending-work "$PERSONA" 2>/dev/null | wc -l)
        
        # Debug logging
        log_hook_event "DEBUG" "Pending count for $PERSONA: $PENDING_COUNT"
        
        if [ "$PENDING_COUNT" -gt 0 ]; then
            # Prepare next work item
            log_hook_event "WORK:QUEUE" "Preparing next work item for $PERSONA ($PENDING_COUNT remaining)"
            es-work-tracker.sh prepare "$PERSONA"
            
            # Check if work script was created successfully
            if [ -f /tmp/execute-next-work.sh ]; then
                log_hook_event "WORK:QUEUE" "Work script prepared successfully for $PERSONA"
                
                # For PostToolUse hooks, provide feedback to Claude about the next action
                if is_post_tool_use; then
                    cat << EOF >&2
{
    "decision": "block",
    "reason": "Next work item prepared for $PERSONA. Execute the prepared work script: /tmp/execute-next-work.sh"
}
EOF
                    exit 2
                fi
            else
                log_hook_event "WORK:QUEUE" "Failed to prepare work script for $PERSONA"
            fi
        else
            # No more work - log completion but don't trigger handoff here
            # The journal hook will handle transition decisions via pure event sourcing
            log_hook_event "WORK:QUEUE" "No more work for $PERSONA - all work items completed"
            log_hook_event "DEBUG" "Handoff decisions now handled by journal hook via event sourcing"
        fi
    else
        log_hook_event "WORK:QUEUE" "Could not determine valid persona from recent work completion: '$PERSONA'"
    fi
fi

# Priority 2: Check for work blocking - this means we should continue working
if [[ "$command" =~ "WORK:BLOCKED" ]]; then
    # Extract the persona that was blocked
    if [[ "$command" =~ "([A-Z]+) has" ]]; then
        BLOCKED_PERSONA="${BASH_REMATCH[1]}"
        
        # Log that work was blocked
        log_hook_event "WORK:QUEUE" "Work blocked for $BLOCKED_PERSONA, continuing with current persona"
        
        # Don't prepare new work - let the persona handle the blocking issue
        # Remove any prepared work scripts since they may be invalid
        rm -f /tmp/execute-next-work.sh /tmp/execute-next-work.sh.tmp
        
        log_hook_event "DEBUG" "Removed prepared work scripts due to blocking issue"
    fi
fi

# Priority 3: Check for work starting - prepare for potential next item
if [[ "$command" =~ "WORK:STARTED" ]]; then
    # Extract persona if possible
    if [[ "$command" =~ "([A-Z]+):" ]]; then
        STARTED_PERSONA="${BASH_REMATCH[1]}"
        log_hook_event "WORK:QUEUE" "Work started for $STARTED_PERSONA"
        
        # Optionally pre-prepare next work item while current one is executing
        # This is an optimization but not critical
        PENDING_COUNT=$(es-journal-query.sh pending-work "$STARTED_PERSONA" 2>/dev/null | wc -l)
        if [ "$PENDING_COUNT" -gt 1 ]; then
            log_hook_event "DEBUG" "$STARTED_PERSONA has $PENDING_COUNT items total, pre-preparation possible"
        fi
    fi
fi

# REMOVED: All handoff completion detection logic
# REMOVED: All force session end logic
# REMOVED: All persona-work-ready signaling

log_hook_event "DEBUG" "Work queue monitor completed - focusing only on work preparation"
