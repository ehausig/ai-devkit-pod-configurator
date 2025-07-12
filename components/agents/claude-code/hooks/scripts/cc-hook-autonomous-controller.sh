#!/bin/bash
# Autonomous workflow controller hook - FIXED: Better error handling
# Called by the Stop hook to enable continuous autonomous execution

# Source common functions
if [ -f "/usr/local/bin/cc-common.sh" ]; then
    source /usr/local/bin/cc-common.sh
elif [ -f "cc-common.sh" ]; then
    source cc-common.sh
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Get JSON input
JSON_INPUT=$(cat)

# Extract session info
SESSION_ID=$(extract_json_field "$JSON_INPUT" '.session_id' 'unknown')
STOP_HOOK_ACTIVE=$(extract_json_field "$JSON_INPUT" '.stop_hook_active' 'false')

# Log hook execution
log_event "AUTONOMOUS:HOOK_START" "Autonomous controller evaluating session $SESSION_ID"

# Check if autonomous mode is enabled
AUTONOMOUS_MODE="${CLAUDE_AUTONOMOUS_MODE:-false}"
if [ "$AUTONOMOUS_MODE" != "true" ]; then
    log_event "AUTONOMOUS:DISABLED" "Autonomous mode not enabled, allowing normal session end"
    exit 0  # Let normal session end
fi

# Prevent infinite recursion if stop hook is already active
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    log_event "AUTONOMOUS:RECURSION_PREVENTED" "Stop hook already active, preventing recursion"
    exit 0
fi

log_event "AUTONOMOUS:ENABLED" "Autonomous mode active - FIXED: Better error handling"

# FIXED: Execute work with proper error handling
execute_full_autonomous_cycle() {
    local max_iterations=20  # Prevent infinite loops
    local iteration=0
    
    while [ $iteration -lt $max_iterations ]; do
        iteration=$((iteration + 1))
        log_event "AUTONOMOUS:ITERATION" "Autonomous cycle iteration $iteration"
        
        # Check for unprocessed handoffs first
        UNPROCESSED_TARGET=$(es-journal-query.sh recent-handoff-unprocessed 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$UNPROCESSED_TARGET" ] && [[ "$UNPROCESSED_TARGET" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
            log_event "AUTONOMOUS:HANDOFF_FOUND" "Processing unprocessed handoff to $UNPROCESSED_TARGET"
            
            # Initialize persona
            PERSONA_LOWER=$(echo $UNPROCESSED_TARGET | tr '[:upper:]' '[:lower:]')
            INIT_SCRIPT="persona-${PERSONA_LOWER}-init.sh"
            
            if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
                log_event "AUTONOMOUS:INITIALIZING" "Initializing $UNPROCESSED_TARGET persona"
                "$INIT_SCRIPT" >/dev/null 2>&1
                
                # Process work for this persona
                if process_persona_work "$UNPROCESSED_TARGET"; then
                    log_event "AUTONOMOUS:PERSONA_COMPLETE" "$UNPROCESSED_TARGET work completed"
                    continue  # Check for next persona
                else
                    log_event "AUTONOMOUS:PERSONA_WORK_CONTINUES" "$UNPROCESSED_TARGET has more work or encountered issues"
                    # Don't fail the whole cycle - persona might have partial progress
                    continue
                fi
            fi
        fi
        
        # Check for pending work across personas
        NEXT_PERSONA=$(es-journal-query.sh transition-needed 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$NEXT_PERSONA" ] && [[ "$NEXT_PERSONA" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
            log_event "AUTONOMOUS:TRANSITION_FOUND" "Processing pending work for $NEXT_PERSONA"
            
            # Initialize persona if needed
            PERSONA_LOWER=$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')
            INIT_SCRIPT="persona-${PERSONA_LOWER}-init.sh"
            
            if command -v "$INIT_SCRIPT" >/dev/null 2>&1; then
                log_event "AUTONOMOUS:INITIALIZING" "Initializing $NEXT_PERSONA persona"
                "$INIT_SCRIPT" >/dev/null 2>&1
            fi
            
            # Process work for this persona
            if process_persona_work "$NEXT_PERSONA"; then
                log_event "AUTONOMOUS:PERSONA_COMPLETE" "$NEXT_PERSONA work completed"
                continue  # Check for next persona
            else
                log_event "AUTONOMOUS:PERSONA_WORK_CONTINUES" "$NEXT_PERSONA has more work"
                continue
            fi
        fi
        
        # No more work found
        log_event "AUTONOMOUS:NO_MORE_WORK" "No more work found, cycle complete"
        return 0
    done
    
    log_event "AUTONOMOUS:MAX_ITERATIONS" "Reached maximum iterations, stopping"
    return 1
}

# FIXED: Process all work for a specific persona with better error handling
process_persona_work() {
    local persona="$1"
    local max_work_items=10  # Safety limit
    local work_count=0
    local consecutive_failures=0
    local max_consecutive_failures=3
    
    log_event "AUTONOMOUS:PROCESS_PERSONA" "Processing work for $persona"
    
    while [ $work_count -lt $max_work_items ]; do
        work_count=$((work_count + 1))
        
        # Check for pending work
        PENDING_COUNT=$(es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l || echo "0")
        
        if [ "$PENDING_COUNT" -eq 0 ]; then
            log_event "AUTONOMOUS:NO_PENDING" "No pending work for $persona"
            
            # Work complete - handoff should have been executed by work script
            return 0  # Success - persona complete
        fi
        
        # Execute next work item
        log_event "AUTONOMOUS:EXECUTING_WORK" "Executing work item $work_count for $persona"
        
        # Prepare work script
        es-work-tracker.sh prepare "$persona" >/dev/null 2>&1
        
        if [ -f /tmp/execute-next-work.sh ]; then
            # Execute work script directly in hook context
            /tmp/execute-next-work.sh >/dev/null 2>&1
            WORK_EXIT_CODE=$?
            
            if [ $WORK_EXIT_CODE -eq 0 ]; then
                log_event "AUTONOMOUS:WORK_SUCCESS" "Work item $work_count completed for $persona"
                consecutive_failures=0  # Reset failure counter
                # Continue to next work item
            elif [ $WORK_EXIT_CODE -eq 2 ]; then
                # This shouldn't happen with fixed scripts
                log_event "AUTONOMOUS:UNEXPECTED_EXIT_2" "Work item returned exit 2 (should not happen)"
                consecutive_failures=$((consecutive_failures + 1))
            else
                log_event "AUTONOMOUS:WORK_FAILED" "Work item $work_count failed for $persona (exit code $WORK_EXIT_CODE)"
                consecutive_failures=$((consecutive_failures + 1))
                
                # Check if we've hit too many consecutive failures
                if [ $consecutive_failures -ge $max_consecutive_failures ]; then
                    log_event "AUTONOMOUS:TOO_MANY_FAILURES" "Too many consecutive failures for $persona"
                    return 1
                fi
                
                # Continue trying other work items
            fi
        else
            log_event "AUTONOMOUS:NO_WORK_SCRIPT" "No work script prepared for $persona"
            return 1
        fi
    done
    
    log_event "AUTONOMOUS:MAX_WORK_ITEMS" "Reached maximum work items for $persona"
    return 0  # Don't fail - we made progress
}

# Execute the full autonomous cycle
log_event "AUTONOMOUS:STARTING_CYCLE" "Starting autonomous execution cycle"

if execute_full_autonomous_cycle; then
    log_event "AUTONOMOUS:CYCLE_SUCCESS" "Autonomous cycle completed successfully"
    
    # Provide completion feedback
    cat << EOF
{
  "decision": "block",
  "reason": "AUTONOMOUS EXECUTION COMPLETE: Successfully executed the development workflow autonomously. Check the journal for full execution details."
}
EOF
    exit 0
else
    log_event "AUTONOMOUS:CYCLE_INCOMPLETE" "Autonomous cycle incomplete - some work may remain"
    
    # Provide feedback with next steps
    cat << EOF
{
  "decision": "block",
  "reason": "AUTONOMOUS EXECUTION PARTIAL: The autonomous workflow made progress but requires manual intervention. Check the journal for details and continue where needed."
}
EOF
    exit 0
fi
