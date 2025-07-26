#!/bin/bash
# Orchestration hook for autonomous development system
# Serves as a backup mechanism if persona chaining is interrupted
# Primary autonomy is now handled by personas invoking each other directly

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
    local assigned=0
    local completed=0
    
    # Count assigned work
    if grep -q "WORK_ASSIGNED | $persona" "$JOURNAL_PATH" 2>/dev/null; then
        assigned=$(grep "WORK_ASSIGNED | $persona" "$JOURNAL_PATH" | wc -l | tr -d ' ')
    fi
    
    # Count completed work
    if grep -q "WORK_COMPLETE | $persona" "$JOURNAL_PATH" 2>/dev/null; then
        completed=$(grep "WORK_COMPLETE | $persona" "$JOURNAL_PATH" | wc -l | tr -d ' ')
    fi
    
    local pending=$((assigned - completed))
    [ $pending -lt 0 ] && pending=0
    echo $pending
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
    
    # Handle both formats: "ARCHITECT->DEVELOPER" and "DEVELOPER-&gt;QA"
    # The &gt; is HTML entity for > that might appear in some outputs
    if [[ "$handoff_personas" =~ -\> ]] || [[ "$handoff_personas" =~ -\&gt\; ]]; then
        # Extract the TO persona (after the arrow)
        local to_persona=""
        if [[ "$handoff_personas" =~ -\> ]]; then
            to_persona=$(echo "$handoff_personas" | sed 's/.*->//')
        else
            to_persona=$(echo "$handoff_personas" | sed 's/.*-&gt;//')
        fi
        
        # Clean up any trailing colons or spaces
        to_persona=$(echo "$to_persona" | sed 's/:.*$//' | xargs)
        
        debug_log "Extracted TO persona: '$to_persona' from '$handoff_personas'"
        
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

# Look for the most recent NEXT_COMMAND directive in the journal
NEXT_CMD=$(grep "NEXT_COMMAND |" "$JOURNAL_PATH" 2>/dev/null | tail -1 | cut -d'|' -f4 | xargs)

if [ -n "$NEXT_CMD" ]; then
    debug_log "Found NEXT_COMMAND in journal: $NEXT_CMD"
    
    # Check if this command has already been executed by looking for subsequent events
    # Get the timestamp of the NEXT_COMMAND
    NEXT_CMD_TIME=$(grep "NEXT_COMMAND |" "$JOURNAL_PATH" 2>/dev/null | tail -1 | cut -d' ' -f1)
    
    # Check for any WORK_STARTED events after this time
    if [ -n "$NEXT_CMD_TIME" ]; then
        LATER_WORK=$(grep "WORK_STARTED" "$JOURNAL_PATH" 2>/dev/null | while read line; do
            event_time=$(echo "$line" | cut -d' ' -f1)
            if [[ "$event_time" > "$NEXT_CMD_TIME" ]]; then
                echo "found"
                break
            fi
        done)
        
        if [ "$LATER_WORK" = "found" ]; then
            debug_log "NEXT_COMMAND already executed (found later WORK_STARTED)"
            NEXT_CMD=""
        fi
    fi
fi

# If no NEXT_COMMAND or it was already executed, check for active personas
if [ -z "$NEXT_CMD" ]; then
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
        local project_init=0
        local architect_assigned=0
        local work_started=0
        
        grep -q "PROJECT_INIT" "$JOURNAL_PATH" 2>/dev/null && project_init=1
        grep -q "WORK_ASSIGNED | ARCHITECT" "$JOURNAL_PATH" 2>/dev/null && architect_assigned=1
        grep -q "WORK_STARTED" "$JOURNAL_PATH" 2>/dev/null && work_started=1
        
        if [ "$project_init" -eq 1 ] || [ "$architect_assigned" -eq 1 ]; then
            if [ "$work_started" -eq 0 ]; then
                # Project initialized but no work started
                ACTIVE_PERSONA="ARCHITECT"
                PENDING_COUNT=1
                debug_log "Project initialized but not started, activating ARCHITECT"
            fi
        fi
    fi
    
    # Also check for any persona with assigned work that hasn't been started
    if [ -z "$ACTIVE_PERSONA" ]; then
        for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            # Check if there are WORK_ASSIGNED events without corresponding WORK_STARTED
            local assigned=0
            local started=0
            
            grep -q "WORK_ASSIGNED | $persona" "$JOURNAL_PATH" 2>/dev/null && \
                assigned=$(grep "WORK_ASSIGNED | $persona" "$JOURNAL_PATH" | wc -l | tr -d ' ')
            
            grep -q "WORK_STARTED | $persona" "$JOURNAL_PATH" 2>/dev/null && \
                started=$(grep "WORK_STARTED | $persona" "$JOURNAL_PATH" | wc -l | tr -d ' ')
            
            if [ "$assigned" -gt "$started" ]; then
                ACTIVE_PERSONA="$persona"
                PENDING_COUNT=$((assigned - started))
                debug_log "Found $persona with unstarted work: $assigned assigned, $started started"
                break
            fi
        done
    fi
fi

# Determine what to do next
if [ -n "$NEXT_CMD" ]; then
    # We have an explicit next command from the journal
    debug_log "Executing NEXT_COMMAND: $NEXT_CMD"
    
    # Return error to trigger Claude to process the command
    echo "AUTONOMOUS DEVELOPMENT: Execute next command from journal: $NEXT_CMD" >&2
    exit 2
elif [ -n "$ACTIVE_PERSONA" ] && [ "$PENDING_COUNT" -gt 0 ]; then
    # We found work but no explicit command, suggest the persona command
    PERSONA_LOWER=$(echo "$ACTIVE_PERSONA" | tr '[:upper:]' '[:lower:]')
    debug_log "Suggesting $ACTIVE_PERSONA persona command"
    
    echo "AUTONOMOUS DEVELOPMENT: $ACTIVE_PERSONA has $PENDING_COUNT pending tasks. Execute: /$PERSONA_LOWER" >&2
    exit 2
fi

# No work found - allow Claude to stop
debug_log "No pending work found, allowing stop"
exit 0
