#!/bin/bash
# Work queue monitor hook logic - FIXED: Proper error handling for autonomous execution
# Called by hook-framework.sh
# Focus: Immediate work execution and persona transitions

# Extract command
command=$(get_command)

# Check if autonomous mode is enabled
AUTONOMOUS_MODE="${CLAUDE_AUTONOMOUS_MODE:-false}"
if [ "$AUTONOMOUS_MODE" != "true" ]; then
    log_hook_event "DEBUG" "Autonomous mode disabled, normal work queue monitoring"
    exit 0
fi

# FIXED: Trigger autonomous execution with proper error handling
if [[ "$command" =~ "WORK:COMPLETED" ]]; then
    # Use centralized journal query instead of regex parsing
    PERSONA=$(es-journal-query.sh work-completed-persona)
    
    if [ -n "$PERSONA" ] && [[ "$PERSONA" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
        log_hook_event "AUTONOMOUS:WORK_COMPLETED" "Detected work completion for $PERSONA"
        
        # Check if more work exists for this persona
        PENDING_COUNT=$(es-journal-query.sh pending-work "$PERSONA" 2>/dev/null | wc -l)
        
        log_hook_event "DEBUG" "Pending count for $PERSONA: $PENDING_COUNT"
        
        if [ "$PENDING_COUNT" -gt 0 ]; then
            # More work exists - execute next item immediately
            log_hook_event "AUTONOMOUS:CONTINUE_WORK" "Executing next work item for $PERSONA ($PENDING_COUNT remaining)"
            
            # Prepare and execute work directly in hook
            es-work-tracker.sh prepare "$PERSONA" >/dev/null 2>&1
            
            if [ -f /tmp/execute-next-work.sh ]; then
                log_hook_event "AUTONOMOUS:EXECUTING_NEXT" "Executing prepared work script for $PERSONA"
                
                # CRITICAL FIX: Execute work script and handle ALL exit codes properly
                /tmp/execute-next-work.sh >/dev/null 2>&1
                WORK_EXIT_CODE=$?
                
                if [ $WORK_EXIT_CODE -eq 0 ]; then
                    log_hook_event "AUTONOMOUS:WORK_SUCCESS" "Next work item completed for $PERSONA"
                    
                    # Provide feedback to continue the cycle
                    cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS WORK CONTINUATION: Successfully executed next work item for $PERSONA. The autonomous system will continue processing remaining work items automatically."
}
EOF
                    exit 2
                elif [ $WORK_EXIT_CODE -eq 2 ]; then
                    # CRITICAL: Exit code 2 should not be used by work scripts anymore
                    log_hook_event "AUTONOMOUS:UNEXPECTED_EXIT_2" "Work script returned exit code 2 (should not happen)"
                    
                    # Treat as normal failure and continue
                    log_hook_event "AUTONOMOUS:WORK_FAILED" "Next work item failed for $PERSONA (exit code 2)"
                    
                    # Don't block the entire flow, just log the issue
                    exit 0
                else
                    # Exit code 1 or other - normal failure, log but continue
                    log_hook_event "AUTONOMOUS:WORK_FAILED" "Next work item failed for $PERSONA (exit code $WORK_EXIT_CODE)"
                    
                    # Don't block autonomous flow for normal failures
                    exit 0
                fi
            else
                log_hook_event "AUTONOMOUS:PREP_FAILED" "Failed to prepare next work for $PERSONA"
                exit 0
            fi
        else
            # No more work - handoff should have been triggered by work script
            log_hook_event "AUTONOMOUS:NO_MORE_WORK" "No more work for $PERSONA - handoff should have been executed"
            
            # Check if handoff was completed
            RECENT_HANDOFF=$(es-journal-query.sh recent-context "$PERSONA" 5 | grep -c "HANDOFF:COMPLETED" || echo "0")
            
            if [ "$RECENT_HANDOFF" -gt 0 ]; then
                log_hook_event "AUTONOMOUS:HANDOFF_DETECTED" "Handoff already completed by work script"
            else
                log_hook_event "AUTONOMOUS:HANDOFF_MISSING" "Expected handoff not found - may need manual intervention"
            fi
            
            # Don't block - let the Stop hook handle any transitions
            exit 0
        fi
    else
        log_hook_event "AUTONOMOUS:PERSONA_UNKNOWN" "Could not determine valid persona from work completion: '$PERSONA'"
    fi
fi

# Check for handoff completion (persona transitions)
if [[ "$command" =~ "HANDOFF:COMPLETED" ]]; then
    log_hook_event "AUTONOMOUS:HANDOFF_DETECTED" "Handoff completion detected"
    
    # Extract target persona from handoff
    HANDOFF_TARGET=$(es-journal-query.sh recent-handoff-unprocessed 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$HANDOFF_TARGET" ] && [[ "$HANDOFF_TARGET" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
        log_hook_event "AUTONOMOUS:PROCESSING_HANDOFF" "Processing handoff to $HANDOFF_TARGET"
        
        # Initialize target persona
        TARGET_INIT="persona-$(echo $HANDOFF_TARGET | tr '[:upper:]' '[:lower:]')-init.sh"
        if command -v "$TARGET_INIT" >/dev/null 2>&1; then
            # Execute init script
            "$TARGET_INIT" >/dev/null 2>&1
            INIT_EXIT_CODE=$?
            
            if [ $INIT_EXIT_CODE -eq 0 ]; then
                log_hook_event "AUTONOMOUS:TARGET_INIT" "$HANDOFF_TARGET initialized from handoff"
                
                # Start work immediately
                es-work-tracker.sh prepare "$HANDOFF_TARGET" >/dev/null 2>&1
                
                if [ -f /tmp/execute-next-work.sh ]; then
                    log_hook_event "AUTONOMOUS:HANDOFF_WORK_START" "Starting work for $HANDOFF_TARGET from handoff"
                    
                    # Execute work with proper error handling
                    /tmp/execute-next-work.sh >/dev/null 2>&1
                    WORK_EXIT_CODE=$?
                    
                    if [ $WORK_EXIT_CODE -eq 0 ]; then
                        log_hook_event "AUTONOMOUS:HANDOFF_WORK_SUCCESS" "Started work successfully for $HANDOFF_TARGET"
                        
                        cat << EOF >&2
{
    "decision": "block",
    "reason": "AUTONOMOUS HANDOFF PROCESSING: Successfully initialized $HANDOFF_TARGET and started their work automatically. The workflow continues autonomously."
}
EOF
                        exit 2
                    else
                        # Don't fail the whole flow for work failures
                        log_hook_event "AUTONOMOUS:HANDOFF_WORK_FAILED" "Failed to start work for $HANDOFF_TARGET (exit code $WORK_EXIT_CODE)"
                        exit 0
                    fi
                else
                    log_hook_event "AUTONOMOUS:NO_WORK_PREPARED" "No work script prepared for $HANDOFF_TARGET"
                    exit 0
                fi
            else
                log_hook_event "AUTONOMOUS:TARGET_INIT_FAILED" "Failed to initialize $HANDOFF_TARGET from handoff"
                exit 0
            fi
        else
            log_hook_event "AUTONOMOUS:INIT_SCRIPT_MISSING" "Init script not found: $TARGET_INIT"
            exit 0
        fi
    fi
fi

# Normal hook completion (no autonomous action needed)
log_hook_event "DEBUG" "Work queue monitor completed - no autonomous action required"
exit 0
