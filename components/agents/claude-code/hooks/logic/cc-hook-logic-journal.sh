#!/bin/bash
# Journal hook logic for Stop events - REFACTORED to pure event sourcing
# Called by hook-framework.sh

# Check if this is a stop hook that's already active to prevent loops
stop_hook_active=$(extract_json_field "$JSON_INPUT" '.stop_hook_active' 'false')

if [ "$stop_hook_active" = "true" ]; then
    # Don't create recursive journal entries or continuations
    log_hook_event "DEBUG" "Stop hook already active, preventing recursion"
    exit 0
fi

# Log the session completion first
log_hook_event "INFO" "Session $SESSION_ID completed - Claude Code session completed"
log_hook_event "DEBUG" "Stop hook executing - checking for transitions via journal queries"

# PURE EVENT SOURCING APPROACH - No file dependencies
# All transition decisions based solely on journal state

# Priority 1: Check for unprocessed handoffs via journal queries
log_hook_event "DEBUG" "Priority 1: Checking for unprocessed handoffs via journal"
UNPROCESSED_TARGET=$(es-journal-query.sh recent-handoff-unprocessed 2>/dev/null)
UNPROCESSED_EXIT_CODE=$?

if [ $UNPROCESSED_EXIT_CODE -eq 0 ] && [ -n "$UNPROCESSED_TARGET" ] && [[ "$UNPROCESSED_TARGET" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
    log_hook_event "AUTOMATION:JOURNAL_TRANSITION" "Executing automatic continuation with $UNPROCESSED_TARGET persona via journal query"
    
    # Log transition events for better tracking
    log_hook_event "TRANSITION:STARTED" "Initializing $UNPROCESSED_TARGET persona from unprocessed handoff"
    
    # Execute the persona initialization script directly
    NEXT_PERSONA_LOWER=$(echo $UNPROCESSED_TARGET | tr '[:upper:]' '[:lower:]')
    INIT_SCRIPT="persona-${NEXT_PERSONA_LOWER}-init.sh"
    
    log_hook_event "AUTOMATION:EXECUTING" "Directly executing $INIT_SCRIPT in hook for unprocessed handoff"
    
    # Execute the persona initialization script
    if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
        # Capture the output to provide to Claude
        INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
        INIT_EXIT_CODE=$?
        
        if [ $INIT_EXIT_CODE -eq 0 ]; then
            log_hook_event "AUTOMATION:SUCCESS" "$UNPROCESSED_TARGET persona initialized successfully from unprocessed handoff"
            log_hook_event "TRANSITION:COMPLETED" "$UNPROCESSED_TARGET persona active"
            
            # Check if there's executable work ready
            if [ -f /tmp/execute-next-work.sh ]; then
                log_hook_event "AUTOMATION:WORK_READY" "Work script prepared for $UNPROCESSED_TARGET"
                
                # Provide Claude with the initialization output and next steps
                cat << EOF >&2
{
    "decision": "block",
    "reason": "$UNPROCESSED_TARGET persona initialized successfully from unprocessed handoff. Work is ready to execute. Run: /tmp/execute-next-work.sh"
}
EOF
            else
                # Provide Claude with initialization output
                cat << EOF >&2
{
    "decision": "block", 
    "reason": "$UNPROCESSED_TARGET persona initialized successfully from unprocessed handoff. Check pending work with: es-journal-query.sh pending-work $UNPROCESSED_TARGET"
}
EOF
            fi
        else
            log_hook_event "AUTOMATION:FAILED" "$UNPROCESSED_TARGET initialization failed with exit code $INIT_EXIT_CODE"
            
            # Provide error details to Claude
            cat << EOF >&2
{
    "decision": "block",
    "reason": "$UNPROCESSED_TARGET persona initialization failed. Error: $INIT_OUTPUT"
}
EOF
        fi
    else
        log_hook_event "AUTOMATION:ERROR" "Could not find $INIT_SCRIPT command"
        
        cat << EOF >&2
{
    "decision": "block",
    "reason": "Could not find $INIT_SCRIPT. Please run: persona-$(echo $UNPROCESSED_TARGET | tr '[:upper:]' '[:lower:]')-init.sh"
}
EOF
    fi
    
    exit 2
else
    log_hook_event "DEBUG" "No unprocessed handoffs found via journal query (exit code: $UNPROCESSED_EXIT_CODE, target: '$UNPROCESSED_TARGET')"
fi

# Priority 2: Check for pending work items across all personas using enhanced query
log_hook_event "DEBUG" "Priority 2: Checking for pending work across all personas via journal"
TRANSITION_TARGET=$(es-journal-query.sh transition-needed 2>/dev/null)
TRANSITION_EXIT_CODE=$?

if [ $TRANSITION_EXIT_CODE -eq 0 ] && [ -n "$TRANSITION_TARGET" ] && [[ "$TRANSITION_TARGET" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
    log_hook_event "AUTOMATION:DETECTED" "Found pending work or handoff need for $TRANSITION_TARGET via journal query"
    
    # Get pending work count for logging
    PENDING_COUNT=$(es-journal-query.sh pending-work "$TRANSITION_TARGET" 2>/dev/null | wc -l || echo "0")
    
    # Log transition events
    log_hook_event "TRANSITION:STARTED" "Initializing $TRANSITION_TARGET persona for pending work ($PENDING_COUNT items)"
    
    # Execute persona initialization directly
    PERSONA_LOWER=$(echo $TRANSITION_TARGET | tr '[:upper:]' '[:lower:]')
    INIT_SCRIPT="persona-${PERSONA_LOWER}-init.sh"
    
    log_hook_event "AUTOMATION:EXECUTING" "Directly executing $INIT_SCRIPT for pending work"
    
    if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
        INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
        INIT_EXIT_CODE=$?
        
        if [ $INIT_EXIT_CODE -eq 0 ]; then
            log_hook_event "AUTOMATION:SUCCESS" "$TRANSITION_TARGET persona initialized for pending work"
            log_hook_event "TRANSITION:COMPLETED" "$TRANSITION_TARGET persona active with $PENDING_COUNT pending items"
            
            cat << EOF >&2
{
    "decision": "block",
    "reason": "$TRANSITION_TARGET persona initialized with $PENDING_COUNT pending work items. Work ready to execute."
}
EOF
        else
            log_hook_event "AUTOMATION:FAILED" "$TRANSITION_TARGET initialization failed"
            
            cat << EOF >&2
{
    "decision": "block",
    "reason": "$TRANSITION_TARGET persona initialization failed for pending work. Check logs."
}
EOF
        fi
    else
        cat << EOF >&2
{
    "decision": "block",
    "reason": "Found pending work or transition need for $TRANSITION_TARGET. Please run: persona-$(echo $TRANSITION_TARGET | tr '[:upper:]' '[:lower:]')-init.sh"
}
EOF
    fi
    
    exit 2
else
    log_hook_event "DEBUG" "No transitions needed via journal query (exit code: $TRANSITION_EXIT_CODE, target: '$TRANSITION_TARGET')"
fi

# Priority 3: No pending work found - allow normal session completion
log_hook_event "DEBUG" "Priority 3: No pending work or transitions found across all personas"

# Check if we should start a new cycle
RECENT_MERGER_HANDOFF=$(es-journal-query.sh recent-context MERGER 5 2>/dev/null | grep -c "HANDOFF:COMPLETED" || echo "0")

if [ "$RECENT_MERGER_HANDOFF" -gt 0 ]; then
    log_hook_event "AUTOMATION:CYCLE_COMPLETE" "Development cycle completed successfully"
fi

# Final verification - ensure we're not missing any handoffs due to timing
HANDOFF_STATUS=$(es-journal-query.sh handoff-processing-complete 2>/dev/null)
if [ "$HANDOFF_STATUS" = "unprocessed" ]; then
    log_hook_event "DEBUG" "Final check detected unprocessed handoff, but transition-needed query didn't catch it"
    # This shouldn't happen with the new logic, but log it for debugging
fi

# Exit normally (allow session to end)
log_hook_event "DEBUG" "Allowing normal session completion - no transitions needed"
log_hook_event "INFO" "Stop hook completed successfully - session ending normally"

exit 0
