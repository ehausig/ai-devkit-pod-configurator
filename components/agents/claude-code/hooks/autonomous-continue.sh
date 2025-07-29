#!/bin/bash
# Autonomous continuation hook for sub agent system
# Reads NEXT_AGENT directives from journal and prompts delegation

# Journal path
JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Journal logging function
journal_log() {
    local event_type="$1"
    local actor="$2"
    local description="$3"
    local timestamp=$(date -Iseconds)
    echo "${timestamp} | ${event_type} | ${actor} | ${description}" >> "$JOURNAL_PATH"
}

# Debug mode
DEBUG="${DEBUG:-}"
[ -n "$DEBUG" ] && debug_log() { echo "[autonomous-continue.sh] $*" >&2; } || debug_log() { :; }

debug_log "Autonomous continuation hook started"

# Log hook invocation
journal_log "HOOK_INVOKED" "autonomous-continue" "Stop hook triggered"

# Read JSON input from stdin
JSON_INPUT=$(cat)
debug_log "Received input"

# Log that we received input
journal_log "HOOK_DEBUG" "autonomous-continue" "Received hook input from Claude Code"

# Extract hook_event_name using grep and sed (portable)
HOOK_EVENT=$(echo "$JSON_INPUT" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
debug_log "hook_event_name=$HOOK_EVENT"

# Check if this is a Stop event
if [ "$HOOK_EVENT" != "Stop" ]; then
    debug_log "Not a Stop event, exiting"
    journal_log "HOOK_DEBUG" "autonomous-continue" "Not a Stop event: $HOOK_EVENT"
    exit 0
fi

# Check if stop hook is already active (prevent infinite loops)
STOP_ACTIVE=$(echo "$JSON_INPUT" | grep -o '"stop_hook_active"[[:space:]]*:[[:space:]]*[^,}]*' | sed 's/.*:[[:space:]]*//')
if [ "$STOP_ACTIVE" = "true" ]; then
    debug_log "Stop hook already active, exiting to prevent loop"
    journal_log "HOOK_DEBUG" "autonomous-continue" "Stop hook already active, preventing loop"
    exit 0
fi

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    debug_log "Journal not found at $JOURNAL_PATH"
    journal_log "HOOK_ERROR" "autonomous-continue" "Journal not found at $JOURNAL_PATH"
    exit 0
fi

# Check if development cycle is complete
if grep -q "CYCLE_COMPLETE" "$JOURNAL_PATH" 2>/dev/null; then
    debug_log "Development cycle is complete"
    journal_log "HOOK_DEBUG" "autonomous-continue" "Development cycle is complete"
    exit 0
fi

# Function to find the most recent NEXT_AGENT directive
find_next_agent() {
    # Get the last NEXT_AGENT entry
    local next_agent_line=$(grep "NEXT_AGENT" "$JOURNAL_PATH" 2>/dev/null | tail -1)
    
    if [ -z "$next_agent_line" ]; then
        journal_log "HOOK_DEBUG" "autonomous-continue" "No NEXT_AGENT directive found"
        return 1
    fi
    
    # Parse format: "TIMESTAMP | NEXT_AGENT | from_agent | to_agent | description"
    local parts=($(echo "$next_agent_line" | awk -F' \\| ' '{print $3, $4}'))
    
    if [ ${#parts[@]} -lt 2 ]; then
        debug_log "Invalid NEXT_AGENT format: $next_agent_line"
        journal_log "HOOK_ERROR" "autonomous-continue" "Invalid NEXT_AGENT format: $next_agent_line"
        return 1
    fi
    
    local from_agent="${parts[0]}"
    local to_agent="${parts[1]}"
    
    debug_log "Found NEXT_AGENT: $from_agent -> $to_agent"
    journal_log "HOOK_DEBUG" "autonomous-continue" "Found NEXT_AGENT: $from_agent -> $to_agent"
    
    # Get timestamp of this NEXT_AGENT
    local next_agent_time=$(echo "$next_agent_line" | cut -d' ' -f1)
    
    # Check if this agent has already started work after this directive
    local agent_started=$(grep "AGENT_START | $to_agent" "$JOURNAL_PATH" 2>/dev/null | tail -1)
    if [ -n "$agent_started" ]; then
        local start_time=$(echo "$agent_started" | cut -d' ' -f1)
        # Simple string comparison works for ISO timestamps
        if [[ "$start_time" > "$next_agent_time" ]]; then
            debug_log "Agent $to_agent already started after this directive"
            journal_log "HOOK_DEBUG" "autonomous-continue" "Agent $to_agent already started after directive"
            return 1
        fi
    fi
    
    echo "$to_agent"
    return 0
}

# Function to check for pending work
check_pending_work() {
    # Check if any agent has WORK_ASSIGNED without corresponding AGENT_START
    # Using uppercase hyphenated names for consistency
    local agents=("PRODUCT-MANAGER" "ARCHITECT" "DEVELOPER" "QA" "REVIEWER" "MERGER")
    
    for agent_upper in "${agents[@]}"; do
        # Count work assigned (uses uppercase hyphenated)
        local assigned=$(grep "WORK_ASSIGNED | $agent_upper" "$JOURNAL_PATH" 2>/dev/null | wc -l)
        
        # Count work started (uses uppercase hyphenated)
        local started=$(grep "AGENT_START | $agent_upper" "$JOURNAL_PATH" 2>/dev/null | wc -l)
        
        if [ "$assigned" -gt "$started" ]; then
            # Convert to lowercase for delegation
            local agent_lower=$(echo "$agent_upper" | tr '[:upper:]' '[:lower:]')
            debug_log "Found pending work for $agent_lower: $assigned assigned, $started started"
            journal_log "HOOK_INFO" "autonomous-continue" "Found pending work for $agent_lower: $assigned assigned, $started started"
            echo "$agent_lower"
            return 0
        fi
    done
    
    return 1
}

# Try to find the next agent to delegate to
NEXT_AGENT=""

# First, check for NEXT_AGENT directive
if NEXT_AGENT=$(find_next_agent); then
    debug_log "Will delegate to: $NEXT_AGENT"
    journal_log "HOOK_ACTION" "autonomous-continue" "Will delegate to: $NEXT_AGENT"
elif NEXT_AGENT=$(check_pending_work); then
    debug_log "Found agent with pending work: $NEXT_AGENT"
    journal_log "HOOK_ACTION" "autonomous-continue" "Found agent with pending work: $NEXT_AGENT"
else
    debug_log "No next agent found, allowing stop"
    journal_log "HOOK_INFO" "autonomous-continue" "No next agent found, allowing stop"
    exit 0
fi

# If we found a next agent, prompt delegation
if [ -n "$NEXT_AGENT" ]; then
    debug_log "Prompting delegation to $NEXT_AGENT agent"
    journal_log "HOOK_ACTION" "autonomous-continue" "Prompting delegation to $NEXT_AGENT agent"
    
    # Return error to make Claude continue
    echo "AUTONOMOUS DEVELOPMENT: Delegate to the $NEXT_AGENT agent to continue the development process." >&2
    exit 2
fi

# No work found - allow Claude to stop
debug_log "No pending work found, allowing stop"
journal_log "HOOK_INFO" "autonomous-continue" "No pending work found, allowing stop"
exit 0
