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
    
    # CRITICAL: Force session termination to trigger Stop hook
    # This is done by creating a special marker file that the Stop hook will detect
    echo "$NEXT_PERSONA" > /tmp/force-session-end
    
    # Log the forced termination
    log_hook_event "AUTOMATION:FORCE_END" "Forcing session end to trigger $NEXT_PERSONA handoff"
fi

# Check if command indicates work completion
if [[ "$command" =~ "WORK:COMPLETED" ]]; then
    # Extract persona from the command - handle multiple formats
    PERSONA=""
    
    # Try different regex patterns to extract persona
    if [[ "$command" =~ es-journal-log.*WORK:COMPLETED.*[\'\"]*([A-Z]+):[[:space:]] ]]; then
        PERSONA="${BASH_REMATCH[1]}"
    elif [[ "$command" =~ "WORK:COMPLETED.*[\'\"]*([A-Z]+):" ]]; then
        PERSONA="${BASH_REMATCH[1]}"
    elif [[ "$command" =~ ([A-Z]+):[[:space:]] ]]; then
        PERSONA="${BASH_REMATCH[1]}"
    fi
    
    if [ -n "$PERSONA" ]; then
        log_hook_event "WORK:QUEUE" "Detected work completion for $PERSONA"
        
        # Check if more work exists for this persona
        PENDING_COUNT=$(get_pending_count "$PERSONA")
        
        if [ "$PENDING_COUNT" -gt 0 ]; then
            # Prepare next work item
            log_hook_event "WORK:QUEUE" "Preparing next work item for $PERSONA ($PENDING_COUNT remaining)"
            es-work-tracker.sh prepare "$PERSONA"
        else
            # No more work - check if this persona should hand off
            log_hook_event "WORK:QUEUE" "No more work for $PERSONA, triggering auto-handoff"
            
            # CRITICAL: Auto-trigger handoff when all work is complete
            case "$PERSONA" in
                ARCHITECT)
                    echo "DEVELOPER" > /tmp/force-session-end
                    log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering ARCHITECT handoff to DEVELOPER"
                    ;;
                DEVELOPER)
                    echo "QA" > /tmp/force-session-end
                    log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering DEVELOPER handoff to QA"
                    ;;
                QA)
                    # QA handoff logic depends on test results
                    local failed=$(es-journal-query.sh recent-context QA | grep -c "QA:FAILED" || echo "0")
                    if [ $failed -eq 0 ]; then
                        echo "REVIEWER" > /tmp/force-session-end
                        log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering QA handoff to REVIEWER"
                    else
                        echo "DEVELOPER" > /tmp/force-session-end
                        log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering QA handoff to DEVELOPER (fixes needed)"
                    fi
                    ;;
                REVIEWER)
                    # REVIEWER handoff logic depends on review results
                    local issues=$(es-journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:ISSUE" || echo "0")
                    if [ $issues -eq 0 ]; then
                        echo "MERGER" > /tmp/force-session-end
                        log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering REVIEWER handoff to MERGER"
                    else
                        echo "DEVELOPER" > /tmp/force-session-end
                        log_hook_event "AUTOMATION:AUTO_HANDOFF" "Auto-triggering REVIEWER handoff to DEVELOPER (changes needed)"
                    fi
                    ;;
                MERGER)
                    # MERGER completes the cycle
                    log_hook_event "AUTOMATION:CYCLE_COMPLETE" "Development cycle completed by MERGER"
                    ;;
            esac
        fi
    else
        log_hook_event "WORK:QUEUE" "Could not extract persona from command: $command"
    fi
fi

# Check for handoff completion commands
if [[ "$command" =~ "HANDOFF:COMPLETED" ]]; then
    # Extract the target persona from the handoff message
    if [[ "$command" =~ "handed off to ([A-Z]+)" ]]; then
        TARGET_PERSONA="${BASH_REMATCH[1]}"
        
        # Force session end after handoff
        echo "$TARGET_PERSONA" > /tmp/force-session-end
        log_hook_event "AUTOMATION:FORCE_END" "Forcing session end after handoff to $TARGET_PERSONA"
    fi
fi

# Check for handoff blocked - this means we should continue working
if [[ "$command" =~ "HANDOFF:BLOCKED" ]]; then
    # Extract the persona that was blocked
    if [[ "$command" =~ "([A-Z]+) has" ]]; then
        BLOCKED_PERSONA="${BASH_REMATCH[1]}"
        
        # Log that handoff was blocked
        log_hook_event "AUTOMATION:HANDOFF_BLOCKED" "Handoff blocked for $BLOCKED_PERSONA, continuing work"
        
        # Don't force session end - let the persona continue working
        # Remove any force-session-end marker
        rm -f /tmp/force-session-end
    fi
fi
