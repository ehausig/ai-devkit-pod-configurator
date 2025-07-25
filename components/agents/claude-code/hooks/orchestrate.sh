#!/bin/bash
# Orchestration hook for autonomous development system
# Runs after Claude Code completes a response to check for pending work

# Journal path
JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Debug mode
DEBUG="${DEBUG:-}"
[ -n "$DEBUG" ] && debug_log() { echo "[orchestrate.sh] $*" >&2; } || debug_log() { :; }

debug_log "Orchestration hook started"

# Read JSON input from stdin
JSON_INPUT=$(cat)
debug_log "Received input"

# Extract hook_event_name using grep and sed (portable)
HOOK_EVENT=$(echo "$JSON_INPUT" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
debug_log "hook_event_name=$HOOK_EVENT"

# Check if this is a Stop event
if [ "$HOOK_EVENT" != "Stop" ]; then
    debug_log "Not a Stop event, exiting"
    exit 0
fi

# Check if stop hook is already active (prevent infinite loops)
STOP_ACTIVE=$(echo "$JSON_INPUT" | grep -o '"stop_hook_active"[[:space:]]*:[[:space:]]*[^,}]*' | sed 's/.*:[[:space:]]*//')
if [ "$STOP_ACTIVE" = "true" ]; then
    debug_log "Stop hook already active, exiting to prevent loop"
    exit 0
fi

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    debug_log "Journal not found at $JOURNAL_PATH"
    exit 0
fi

# Function to count pending work for a persona
count_pending_work() {
    local persona="$1"
    local assigned=$(grep -c "WORK_ASSIGNED | $persona" "$JOURNAL_PATH" 2>/dev/null || echo 0)
    local completed=$(grep -c "WORK_COMPLETE | $persona" "$JOURNAL_PATH" 2>/dev/null || echo 0)
    echo $((assigned - completed))
}

# Function to find active persona with pending work
find_active_persona() {
    for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
        local pending=$(count_pending_work "$persona")
        if [ "$pending" -gt 0 ]; then
            debug_log "$persona has $pending pending tasks"
            echo "$persona $pending"
            return 0
        fi
    done
    return 1
}

# Function to check for unprocessed handoffs
check_last_handoff() {
    # Get the last handoff event
    local last_handoff=$(grep "HANDOFF |" "$JOURNAL_PATH" 2>/dev/null | tail -1)
    if [ -z "$last_handoff" ]; then
        return 1
    fi
    
    # Extract TO persona from handoff (format: ARCHITECT->DEVELOPER)
    local handoff_personas=$(echo "$last_handoff" | cut -d'|' -f3 | xargs)
    if [[ "$handoff_personas" =~ -\> ]]; then
        local to_persona=$(echo "$handoff_personas" | cut -d'>' -f2)
        local handoff_time=$(echo "$last_handoff" | cut -d' ' -f1)
        
        # Check if this persona has started work after the handoff
        local work_started=$(grep "WORK_STARTED | $to_persona" "$JOURNAL_PATH" 2>/dev/null | tail -1)
        if [ -n "$work_started" ]; then
            local start_time=$(echo "$work_started" | cut -d' ' -f1)
            # Simple string comparison works for ISO timestamps
            if [[ "$start_time" > "$handoff_time" ]]; then
                # Work already started after handoff
                return 1
            fi
        fi
        
        debug_log "Found unprocessed handoff to $to_persona"
        echo "$to_persona"
        return 0
    fi
    
    return 1
}

# Check if development cycle is complete
if grep -q "CYCLE_COMPLETE" "$JOURNAL_PATH" 2>/dev/null; then
    debug_log "Development cycle is complete"
    exit 0
fi

# Find active persona with pending work
ACTIVE_PERSONA=""
PENDING_COUNT=0

if result=$(find_active_persona); then
    ACTIVE_PERSONA=$(echo "$result" | cut -d' ' -f1)
    PENDING_COUNT=$(echo "$result" | cut -d' ' -f2)
    debug_log "Active persona: $ACTIVE_PERSONA with $PENDING_COUNT pending"
fi

# If no active persona, check for unprocessed handoffs
if [ -z "$ACTIVE_PERSONA" ]; then
    if ACTIVE_PERSONA=$(check_last_handoff); then
        PENDING_COUNT=1
        debug_log "Activating $ACTIVE_PERSONA from handoff"
    fi
fi

# If still no active persona, check if we need to start
if [ -z "$ACTIVE_PERSONA" ]; then
    # Check if project was initialized or ARCHITECT has work
    PROJECT_INIT=$(grep -c "PROJECT_INIT" "$JOURNAL_PATH" 2>/dev/null || echo 0)
    ARCHITECT_ASSIGNED=$(grep -c "WORK_ASSIGNED | ARCHITECT" "$JOURNAL_PATH" 2>/dev/null || echo 0)
    WORK_STARTED=$(grep -c "WORK_STARTED" "$JOURNAL_PATH" 2>/dev/null || echo 0)
    
    if [ "$PROJECT_INIT" -gt 0 ] || [ "$ARCHITECT_ASSIGNED" -gt 0 ]; then
        if [ "$WORK_STARTED" -eq 0 ]; then
            # Project initialized but no work started
            ACTIVE_PERSONA="ARCHITECT"
            PENDING_COUNT=1
            debug_log "Project initialized but not started, activating ARCHITECT"
        fi
    fi
fi

# If we found work to do, continue with that persona
if [ -n "$ACTIVE_PERSONA" ] && [ "$PENDING_COUNT" -gt 0 ]; then
    # Use JSON output to block stopping and provide next command
    PERSONA_LOWER=$(echo "$ACTIVE_PERSONA" | tr '[:upper:]' '[:lower:]')
    
    cat << EOF
{
  "decision": "block",
  "reason": "Continue with $ACTIVE_PERSONA persona - $PENDING_COUNT pending tasks. Run /$PERSONA_LOWER"
}
EOF
    
    debug_log "Blocking stop, continuing with $ACTIVE_PERSONA"
    exit 0
fi

# No work found - allow Claude to stop
debug_log "No pending work found, allowing stop"
exit 0
