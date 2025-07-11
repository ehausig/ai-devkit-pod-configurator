#!/bin/bash
# Journal hook logic for Stop events
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
log_hook_event "DEBUG" "Stop hook executing - checking for handoff signals"

# Priority 1: Check for forced session end (from handoff or work completion)
if [ -f /tmp/force-session-end ]; then
    NEXT_PERSONA=$(cat /tmp/force-session-end 2>/dev/null)
    
    if [ -n "$NEXT_PERSONA" ] && [[ "$NEXT_PERSONA" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
        log_hook_event "AUTOMATION:FORCED_CONTINUE" "Executing automatic continuation with $NEXT_PERSONA persona"
        
        # Clean up signal files first
        rm -f /tmp/force-session-end /tmp/persona-work-ready /tmp/force-session-end.tmp
        
        # CRITICAL: Execute the next persona initialization directly in the hook
        NEXT_PERSONA_LOWER=$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')
        INIT_SCRIPT="persona-${NEXT_PERSONA_LOWER}-init.sh"
        
        log_hook_event "AUTOMATION:EXECUTING" "Directly executing $INIT_SCRIPT in hook"
        
        # Execute the persona initialization script
        if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
            # Capture the output to provide to Claude
            INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
            INIT_EXIT_CODE=$?
            
            if [ $INIT_EXIT_CODE -eq 0 ]; then
                log_hook_event "AUTOMATION:SUCCESS" "$NEXT_PERSONA persona initialized successfully"
                
                # Check if there's executable work ready
                if [ -f /tmp/execute-next-work.sh ]; then
                    log_hook_event "AUTOMATION:WORK_READY" "Work script prepared for $NEXT_PERSONA"
                    
                    # Provide Claude with the initialization output and next steps
                    cat << EOF >&2
{
    "decision": "block",
    "reason": "$NEXT_PERSONA persona initialized successfully. Work is ready to execute. Run: /tmp/execute-next-work.sh"
}
EOF
                else
                    # Provide Claude with initialization output
                    cat << EOF >&2
{
    "decision": "block", 
    "reason": "$NEXT_PERSONA persona initialized successfully. Check pending work with: es-journal-query.sh pending-work $NEXT_PERSONA"
}
EOF
                fi
            else
                log_hook_event "AUTOMATION:FAILED" "$NEXT_PERSONA initialization failed with exit code $INIT_EXIT_CODE"
                
                # Provide error details to Claude
                cat << EOF >&2
{
    "decision": "block",
    "reason": "$NEXT_PERSONA persona initialization failed. Error: $INIT_OUTPUT"
}
EOF
            fi
        else
            log_hook_event "AUTOMATION:ERROR" "Could not find $INIT_SCRIPT command"
            
            cat << EOF >&2
{
    "decision": "block",
    "reason": "Could not find $INIT_SCRIPT. Please run: persona-$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh"
}
EOF
        fi
        
        exit 2
    else
        log_hook_event "ERROR" "Invalid persona in force-session-end file: '$NEXT_PERSONA'"
        rm -f /tmp/force-session-end
    fi
fi

# Priority 2: Check for pending persona work signal (fallback)
if [ -f /tmp/persona-work-ready ]; then
    NEXT_PERSONA=$(cat /tmp/persona-work-ready 2>/dev/null)
    
    if [ -n "$NEXT_PERSONA" ] && [[ "$NEXT_PERSONA" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
        log_hook_event "AUTOMATION:CONTINUE" "Executing automatic continuation with $NEXT_PERSONA persona"
        
        # Clean up the signal file
        rm -f /tmp/persona-work-ready
        
        # Execute the persona initialization directly
        NEXT_PERSONA_LOWER=$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')
        INIT_SCRIPT="persona-${NEXT_PERSONA_LOWER}-init.sh"
        
        log_hook_event "AUTOMATION:EXECUTING" "Directly executing $INIT_SCRIPT in hook"
        
        if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
            INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
            INIT_EXIT_CODE=$?
            
            if [ $INIT_EXIT_CODE -eq 0 ]; then
                log_hook_event "AUTOMATION:SUCCESS" "$NEXT_PERSONA persona initialized successfully"
                
                cat << EOF >&2
{
    "decision": "block",
    "reason": "$NEXT_PERSONA persona initialized and ready. Check status with: es-journal-query.sh pending-work $NEXT_PERSONA"
}
EOF
            else
                log_hook_event "AUTOMATION:FAILED" "$NEXT_PERSONA initialization failed"
                
                cat << EOF >&2
{
    "decision": "block",
    "reason": "$NEXT_PERSONA persona initialization failed. Manual intervention required."
}
EOF
            fi
        else
            cat << EOF >&2
{
    "decision": "block",
    "reason": "Could not execute $INIT_SCRIPT automatically. Please run manually."
}
EOF
        fi
        
        exit 2
    else
        log_hook_event "ERROR" "Invalid persona in persona-work-ready file: '$NEXT_PERSONA'"
        rm -f /tmp/persona-work-ready
    fi
fi

# Priority 3: Check for pending work items across all personas (deterministic order)
log_hook_event "DEBUG" "Checking for pending work across all personas"
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    PENDING_COUNT=$(es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l || echo "0")
    
    if [ "$PENDING_COUNT" -gt 0 ]; then
        log_hook_event "AUTOMATION:DETECTED" "Found $PENDING_COUNT pending work items for $persona"
        
        # Execute persona initialization directly
        PERSONA_LOWER=$(echo $persona | tr '[:upper:]' '[:lower:]')
        INIT_SCRIPT="persona-${PERSONA_LOWER}-init.sh"
        
        log_hook_event "AUTOMATION:EXECUTING" "Directly executing $INIT_SCRIPT for pending work"
        
        if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
            INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
            INIT_EXIT_CODE=$?
            
            if [ $INIT_EXIT_CODE -eq 0 ]; then
                log_hook_event "AUTOMATION:SUCCESS" "$persona persona initialized for pending work"
                
                cat << EOF >&2
{
    "decision": "block",
    "reason": "$persona persona initialized with $PENDING_COUNT pending work items. Work ready to execute."
}
EOF
            else
                log_hook_event "AUTOMATION:FAILED" "$persona initialization failed"
                
                cat << EOF >&2
{
    "decision": "block",
    "reason": "$persona persona initialization failed for pending work. Check logs."
}
EOF
            fi
        else
            cat << EOF >&2
{
    "decision": "block",
    "reason": "Found $PENDING_COUNT pending work items for $persona. Please run: persona-$(echo $persona | tr '[:upper:]' '[:lower:]')-init.sh"
}
EOF
        fi
        
        exit 2
    fi
done

# No pending work found - allow normal session completion
log_hook_event "DEBUG" "No pending work found across all personas"

# Check if we should start a new cycle
RECENT_MERGER_HANDOFF=$(es-journal-query.sh recent-context MERGER 5 2>/dev/null | grep -c "HANDOFF:COMPLETED" || echo "0")

if [ "$RECENT_MERGER_HANDOFF" -gt 0 ]; then
    log_hook_event "AUTOMATION:CYCLE_COMPLETE" "Development cycle completed successfully"
fi

# Exit normally (allow session to end)
log_hook_event "DEBUG" "Allowing normal session completion"
exit 0
