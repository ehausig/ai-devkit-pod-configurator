#!/bin/bash
# Work queue monitor hook logic
# Called by hook-framework.sh

# Extract command
command=$(get_command)

# Priority 1: Check if a work signal file exists (created by handoff scripts)
# This should only trigger once per handoff and should NOT clean up files here
if [ -f /tmp/persona-work-ready ]; then
    NEXT_PERSONA=$(cat /tmp/persona-work-ready)
    
    # Log that we detected a handoff signal
    log_hook_event "WORK:QUEUE" "Detected work ready signal for $NEXT_PERSONA"
    
    # Prepare the next work item
    es-work-tracker.sh prepare "$NEXT_PERSONA"
    
    # CRITICAL: Create force session end marker for Stop hook
    # Use atomic write to prevent race conditions
    echo "$NEXT_PERSONA" > /tmp/force-session-end.tmp
    mv /tmp/force-session-end.tmp /tmp/force-session-end
    
    # Log the forced termination
    log_hook_event "AUTOMATION:FORCE_END" "Forcing session end to trigger $NEXT_PERSONA handoff"
    
    # Do NOT clean up persona-work-ready here - let Stop hook handle it
    # This prevents race conditions between PostToolUse and Stop hooks
fi

# Priority 2: Check if command indicates work completion
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
            # No more work - check if this persona should hand off
            log_hook_event "WORK:QUEUE" "No more work for $PERSONA, checking for auto-handoff"
            
            # Use centralized handoff logic
            NEXT_PERSONA=$(es-journal-query.sh should-handoff "$PERSONA")
            HANDOFF_EXIT_CODE=$?
            
            if [ $HANDOFF_EXIT_CODE -eq 0 ] && [ -n "$NEXT_PERSONA" ]; then
                # CRITICAL: Auto-trigger handoff when all work is complete
                # Use atomic write operation
                echo "$NEXT_PERSONA" > /tmp/force-session-end.tmp
                mv /tmp/force-session-end.tmp /tmp/force-session-end
                
                # Create backup for debugging
                echo "$NEXT_PERSONA" > "/tmp/force-session-end-backup-$(date +%s)"
                
                # Verify file was created
                if [ -f /tmp/force-session-end ]; then
                    log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering $PERSONA handoff to $NEXT_PERSONA (file created successfully)"
                else
                    log_hook_event "ERROR" "Failed to create force-session-end file for $NEXT_PERSONA"
                fi
            else
                log_hook_event "WORK:QUEUE" "No handoff needed for $PERSONA (exit code: $HANDOFF_EXIT_CODE)"
            fi
        fi
    else
        log_hook_event "WORK:QUEUE" "Could not determine valid persona from recent work completion: '$PERSONA'"
    fi
fi

# Priority 3: Check for handoff completion commands
if [[ "$command" =~ "HANDOFF:COMPLETED" ]]; then
    # Extract the target persona from the handoff message
    if [[ "$command" =~ "handed off to ([A-Z]+)" ]] || [[ "$command" =~ "Handed off to ([A-Z]+)" ]]; then
        TARGET_PERSONA="${BASH_REMATCH[1]}"
        
        # Force session end after handoff using atomic write
        echo "$TARGET_PERSONA" > /tmp/force-session-end.tmp
        mv /tmp/force-session-end.tmp /tmp/force-session-end
        
        log_hook_event "AUTOMATION:FORCE_END" "Forcing session end after handoff to $TARGET_PERSONA"
    fi
fi

# Priority 4: Check for handoff blocked - this means we should continue working
if [[ "$command" =~ "HANDOFF:BLOCKED" ]]; then
    # Extract the persona that was blocked
    if [[ "$command" =~ "([A-Z]+) has" ]]; then
        BLOCKED_PERSONA="${BASH_REMATCH[1]}"
        
        # Log that handoff was blocked
        log_hook_event "AUTOMATION:HANDOFF_BLOCKED" "Handoff blocked for $BLOCKED_PERSONA, continuing work"
        
        # Don't force session end - let the persona continue working
        # Remove any force-session-end marker
        rm -f /tmp/force-session-end /tmp/force-session-end.tmp
    fi
fi
