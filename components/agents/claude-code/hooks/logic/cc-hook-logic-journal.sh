#!/bin/bash
# Journal hook logic for Stop events - SOLUTION B: In-Hook Execution
# Called by hook-framework.sh

# Check if this is a stop hook that's already active to prevent loops
stop_hook_active=$(extract_json_field "$JSON_INPUT" '.stop_hook_active' 'false')

if [ "$stop_hook_active" = "true" ]; then
    # Don't create recursive journal entries or continuations
    log_hook_event "DEBUG" "Stop hook already active, preventing recursion"
    exit 0
fi

# Check if autonomous mode is enabled
AUTONOMOUS_MODE="${CLAUDE_AUTONOMOUS_MODE:-false}"
if [ "$AUTONOMOUS_MODE" != "true" ]; then
    log_hook_event "DEBUG" "Autonomous mode disabled, allowing normal session end"
    exit 0
fi

# Log the session completion first
log_hook_event "INFO" "Session $SESSION_ID completed - Autonomous mode checking for continuation"
log_hook_event "DEBUG" "Stop hook executing - SOLUTION B: In-hook execution approach"

# SOLUTION B: Execute work directly in the hook context
execute_autonomous_work() {
    local persona="$1"
    local work_count="$2"
    
    log_hook_event "AUTONOMOUS:IN_HOOK_EXECUTION" "Executing work for $persona with $work_count pending items"
    
    # Prepare work script
    es-work-tracker.sh prepare "$persona" >/dev/null 2>&1
    
    if [ -f /tmp/execute-next-work.sh ]; then
        log_hook_event "AUTONOMOUS:EXECUTING_WORK" "Running work script for $persona in hook context"
        
        # Execute the work script directly in hook context
        # Capture output for feedback to Claude
        WORK_OUTPUT=$(/tmp/execute-next-work.sh 2>&1)
        WORK_EXIT_CODE=$?
        
        if [ $WORK_EXIT_CODE -eq 0 ]; then
            log_hook_event "AUTONOMOUS:WORK_SUCCESS" "Work script completed successfully for $persona"
            
            # Check if more work exists after completion
            REMAINING_COUNT=$(es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l || echo "0")
            
            if [ "$REMAINING_COUNT" -gt 0 ]; then
                log_hook_event "AUTONOMOUS:MORE_WORK" "$persona has $REMAINING_COUNT remaining work items"
                # Recursively execute more work
                execute_autonomous_work "$persona" "$REMAINING_COUNT"
            else
                log_hook_event "AUTONOMOUS:WORK_COMPLETE" "All work completed for $persona, checking for handoff"
                
                # Check if ready for handoff
                if es-journal-query.sh handoff-ready "$persona" >/dev/null 2>&1; then
                    log_hook_event "AUTONOMOUS:EXECUTING_HANDOFF" "Executing handoff for $persona"
                    
                    # Execute handoff script directly
                    HANDOFF_SCRIPT="persona-$(echo $persona | tr '[:upper:]' '[:lower:]')-handoff.sh"
                    if command -v "$HANDOFF_SCRIPT" >/dev/null 2>&1; then
                        HANDOFF_OUTPUT=$("$HANDOFF_SCRIPT" 2>&1)
                        HANDOFF_EXIT_CODE=$?
                        
                        if [ $HANDOFF_EXIT_CODE -eq 0 ]; then
                            log_hook_event "AUTONOMOUS:HANDOFF_SUCCESS" "Handoff completed for $persona"
                            
                            # Check for next persona
                            NEXT_PERSONA=$(es-journal-query.sh transition-needed 2>/dev/null)
                            if [ $? -eq 0 ] && [ -n "$NEXT_PERSONA" ]; then
                                NEXT_COUNT=$(es-journal-query.sh pending-work "$NEXT_PERSONA" 2>/dev/null | wc -l || echo "0")
                                log_hook_event "AUTONOMOUS:NEXT_PERSONA" "Transitioning to $NEXT_PERSONA with $NEXT_COUNT work items"
                                # Continue with next persona
                                execute_autonomous_work "$NEXT_PERSONA" "$NEXT_COUNT"
                            else
                                log_hook_event "AUTONOMOUS:CYCLE_COMPLETE" "Development cycle completed"
                                return 0
                            fi
                        else
                            log_hook_event "AUTONOMOUS:HANDOFF_FAILED" "Handoff failed for $persona"
                            return 1
                        fi
                    else
                        log_hook_event "AUTONOMOUS:HANDOFF_SCRIPT_MISSING" "Handoff script not found: $HANDOFF_SCRIPT"
                        return 1
                    fi
                else
                    log_hook_event "AUTONOMOUS:NOT_READY_HANDOFF" "$persona not ready for handoff"
                    return 1
                fi
            fi
        else
            log_hook_event "AUTONOMOUS:WORK_FAILED" "Work script failed for $persona with exit code $WORK_EXIT_CODE"
            return 1
        fi
    else
        log_hook_event "AUTONOMOUS:NO_WORK_SCRIPT" "No work script prepared for $persona"
        return 1
    fi
    
    return 0
}

# Priority 1: Check for unprocessed handoffs via journal queries
log_hook_event "DEBUG" "Priority 1: Checking for unprocessed handoffs via journal"
UNPROCESSED_TARGET=$(es-journal-query.sh recent-handoff-unprocessed 2>/dev/null)
UNPROCESSED_EXIT_CODE=$?

if [ $UNPROCESSED_EXIT_CODE -eq 0 ] && [ -n "$UNPROCESSED_TARGET" ] && [[ "$UNPROCESSED_TARGET" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
    log_hook_event "AUTOMATION:JOURNAL_TRANSITION" "Found unprocessed handoff to $UNPROCESSED_TARGET - executing in hook"
    
    # Initialize the persona first
    NEXT_PERSONA_LOWER=$(echo $UNPROCESSED_TARGET | tr '[:upper:]' '[:lower:]')
    INIT_SCRIPT="persona-${NEXT_PERSONA_LOWER}-init.sh"
    
    if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
        log_hook_event "AUTOMATION:EXECUTING" "Initializing $UNPROCESSED_TARGET persona in hook"
        
        # Execute initialization in hook context
        INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
        INIT_EXIT_CODE=$?
        
        if [ $INIT_EXIT_CODE -eq 0 ]; then
            log_hook_event "AUTOMATION:SUCCESS" "$UNPROCESSED_TARGET persona initialized successfully"
            
            # Get work count and execute
            PENDING_COUNT=$(es-journal-query.sh pending-work "$UNPROCESSED_TARGET" 2>/dev/null | wc -l || echo "0")
            
            if [ "$PENDING_COUNT" -gt 0 ]; then
                log_hook_event "AUTONOMOUS:STARTING_WORK" "Starting autonomous work execution for $UNPROCESSED_TARGET"
                
                # Execute work directly in hook
                if execute_autonomous_work "$UNPROCESSED_TARGET" "$PENDING_COUNT"; then
                    log_hook_event "AUTONOMOUS:FULL_SUCCESS" "Autonomous execution completed successfully"
                    
                    # Provide success feedback to Claude
                    cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS EXECUTION COMPLETED: Successfully processed $UNPROCESSED_TARGET work and continued the development workflow autonomously. Check the journal for complete execution details."
}
EOF
                    exit 2
                else
                    log_hook_event "AUTONOMOUS:EXECUTION_FAILED" "Autonomous execution failed"
                    
                    cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS EXECUTION ISSUE: Automatic execution encountered problems. Check journal for details and manually continue with the next work item."
}
EOF
                    exit 2
                fi
            else
                log_hook_event "AUTOMATION:NO_PENDING_WORK" "No pending work for $UNPROCESSED_TARGET"
                exit 0
            fi
        else
            log_hook_event "AUTOMATION:FAILED" "$UNPROCESSED_TARGET initialization failed"
            
            cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS INITIALIZATION FAILED: Could not initialize $UNPROCESSED_TARGET. Please run 'persona-$(echo $UNPROCESSED_TARGET | tr '[:upper:]' '[:lower:]')-init.sh' manually."
}
EOF
            exit 2
        fi
    else
        log_hook_event "AUTOMATION:ERROR" "Could not find $INIT_SCRIPT command"
        exit 0
    fi
else
    log_hook_event "DEBUG" "No unprocessed handoffs found"
fi

# Priority 2: Check for pending work items across all personas
log_hook_event "DEBUG" "Priority 2: Checking for pending work across all personas"
TRANSITION_TARGET=$(es-journal-query.sh transition-needed 2>/dev/null)
TRANSITION_EXIT_CODE=$?

if [ $TRANSITION_EXIT_CODE -eq 0 ] && [ -n "$TRANSITION_TARGET" ] && [[ "$TRANSITION_TARGET" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
    log_hook_event "AUTOMATION:DETECTED" "Found pending work for $TRANSITION_TARGET"
    
    # Get pending work count
    PENDING_COUNT=$(es-journal-query.sh pending-work "$TRANSITION_TARGET" 2>/dev/null | wc -l || echo "0")
    log_hook_event "AUTOMATION:PENDING_COUNT" "$TRANSITION_TARGET has $PENDING_COUNT pending work items"
    
    # Initialize persona if needed
    PERSONA_LOWER=$(echo $TRANSITION_TARGET | tr '[:upper:]' '[:lower:]')
    INIT_SCRIPT="persona-${PERSONA_LOWER}-init.sh"
    
    if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
        log_hook_event "AUTOMATION:EXECUTING" "Initializing $TRANSITION_TARGET persona"
        
        INIT_OUTPUT=$("$INIT_SCRIPT" 2>&1)
        INIT_EXIT_CODE=$?
        
        if [ $INIT_EXIT_CODE -eq 0 ]; then
            log_hook_event "AUTOMATION:SUCCESS" "$TRANSITION_TARGET persona initialized"
            
            # Execute work directly in hook
            if execute_autonomous_work "$TRANSITION_TARGET" "$PENDING_COUNT"; then
                log_hook_event "AUTONOMOUS:FULL_SUCCESS" "Autonomous execution completed for $TRANSITION_TARGET"
                
                cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS EXECUTION COMPLETED: Successfully processed all $TRANSITION_TARGET work items autonomously. The workflow has continued automatically."
}
EOF
                exit 2
            else
                log_hook_event "AUTONOMOUS:EXECUTION_FAILED" "Autonomous execution failed for $TRANSITION_TARGET"
                
                cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS EXECUTION ISSUE: Problems during automatic execution. Check journal and continue manually if needed."
}
EOF
                exit 2
            fi
        else
            log_hook_event "AUTOMATION:FAILED" "$TRANSITION_TARGET initialization failed"
            exit 0
        fi
    else
        log_hook_event "AUTOMATION:ERROR" "Could not find $INIT_SCRIPT"
        exit 0
    fi
else
    log_hook_event "DEBUG" "No transitions needed"
fi

# Priority 3: Check for cycle completion
RECENT_MERGER_HANDOFF=$(es-journal-query.sh recent-context MERGER 5 2>/dev/null | grep -c "HANDOFF:COMPLETED" || echo "0")

if [ "$RECENT_MERGER_HANDOFF" -gt 0 ]; then
    log_hook_event "AUTOMATION:CYCLE_COMPLETE" "Development cycle completed successfully"
    
    cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS CYCLE COMPLETE: Full development cycle completed successfully. All personas have finished their work. Ready for new projects."
}
EOF
    exit 2
fi

# No work found - allow session to end
log_hook_event "DEBUG" "No autonomous work needed, allowing normal session completion"
exit 0
