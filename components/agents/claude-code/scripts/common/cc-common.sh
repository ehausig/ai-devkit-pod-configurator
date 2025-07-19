#!/bin/bash
# Common functions and utilities for Claude Code scripts - UPDATED for pure event sourcing

# Ensure /usr/local/bin is in PATH
export PATH="/usr/local/bin:$PATH"

# Colors for output
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export RED='\033[0;31m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;95m'
export WHITE='\033[1;37m'
export GRAY='\033[0;37m'
export NC='\033[0m' # No Color

# Common paths
export JOURNAL_FILE="$HOME/workspace/JOURNAL.md"
export WORK_SCRIPT="/tmp/execute-next-work.sh"

# Ensure journal exists
ensure_journal() {
    if [ ! -f "$JOURNAL_FILE" ]; then
        echo "# Development Journal" > "$JOURNAL_FILE"
        echo "" >> "$JOURNAL_FILE"
    fi
}

# Extract JSON field using jq with fallback
extract_json_field() {
    local json="$1"
    local field="$2"
    local default="${3:-}"
    
    echo "$json" | jq -r "$field // \"$default\"" 2>/dev/null || echo "$default"
}

# Get current persona with fallback - UPDATED to use es-projection.sh
get_current_persona() {
    local persona=""
    
    # Try es-projection.sh first
    if command -v es-projection.sh >/dev/null 2>&1; then
        # Get the most recently activated persona
        persona=$(grep "TYPE:PERSONA_ACTIVATED" "$JOURNAL_FILE" 2>/dev/null | tail -1 | grep -o 'PERSONA:[^|]*' | cut -d: -f2)
    fi
    
    if [ -z "$persona" ] || [ "$persona" = "UNKNOWN" ]; then
        # Fallback to grep
        persona=$(grep "PERSONA:INIT" "$JOURNAL_FILE" 2>/dev/null | tail -1 | grep -o '\[.*:' | tr -d '[:[]' || echo "UNKNOWN")
    fi
    
    echo "${persona:-UNKNOWN}"
}

# Log with timestamp - UPDATED to use es-event-emit.sh for events
log_event() {
    local tag="$1"
    local message="$2"
    
    # Ensure journal exists
    ensure_journal
    
    # For EVENT types, use es-event-emit.sh
    if [[ "$tag" == "EVENT:"* ]] && command -v es-event-emit.sh >/dev/null 2>&1; then
        local event_type="${tag#EVENT:}"
        es-event-emit.sh "$event_type" "$message"
    else
        # For non-event logs, write directly
        echo "$(date -Iseconds) [$tag] $message" >> "$JOURNAL_FILE"
    fi
}

# Check if work item is completed
is_work_completed() {
    local work_desc="$1"
    grep -q "WORK:COMPLETED.*$work_desc" "$JOURNAL_FILE" 2>/dev/null
}

# Get pending work count for persona - UPDATED to use es-projection.sh
get_pending_count() {
    local persona="${1:-$(get_current_persona)}"
    
    if command -v es-projection.sh >/dev/null 2>&1; then
        es-projection.sh "$persona" "pending_work" 2>/dev/null | wc -l
    else
        # Fallback: count pending work manually
        grep "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null | \
            while read -r line; do
                work_desc=$(echo "$line" | sed 's/.*WORK:PENDING\] //')
                if ! grep -q "WORK:COMPLETED.*$work_desc" "$JOURNAL_FILE" 2>/dev/null; then
                    echo "$line"
                fi
            done | wc -l
    fi
}

# Check if persona is ready for handoff - UPDATED to use es-projection.sh
is_handoff_ready() {
    local persona="${1:-$(get_current_persona)}"
    local pending=$(get_pending_count "$persona")
    [ "$pending" -eq 0 ]
}

# Get next persona in workflow - UPDATED to use es-projection.sh
get_next_persona() {
    local current="$1"
    
    # Use es-projection.sh to check state if available
    if command -v es-projection.sh >/dev/null 2>&1; then
        local state=$(es-projection.sh "$current" "current_state")
        
        # If persona is complete, determine next
        if [ "$state" = "COMPLETE" ]; then
            case "$current" in
                ARCHITECT) echo "DEVELOPER" ;;
                DEVELOPER) 
                    # Check if QA has failures
                    if grep -q "TYPE:WORK_FAILED.*PERSONA:QA" "$JOURNAL_FILE"; then
                        echo "DEVELOPER"
                    else
                        echo "QA"
                    fi
                    ;;
                QA)
                    # Check if tests passed
                    if grep -q "QA:FAILED" "$JOURNAL_FILE" | tail -10; then
                        echo "DEVELOPER"
                    else
                        echo "REVIEWER"
                    fi
                    ;;
                REVIEWER)
                    # Check if approved
                    if grep -q "REVIEWER:ISSUE" "$JOURNAL_FILE" | tail -10; then
                        echo "DEVELOPER"
                    else
                        echo "MERGER"
                    fi
                    ;;
                MERGER) echo "ARCHITECT" ;; # Start new cycle
                *) echo "UNKNOWN" ;;
            esac
        else
            echo "UNKNOWN"
        fi
    else
        # Fallback to hardcoded logic
        case "$current" in
            ARCHITECT) echo "DEVELOPER" ;;
            DEVELOPER) echo "QA" ;;
            QA) echo "REVIEWER" ;;
            REVIEWER) echo "MERGER" ;;
            MERGER) echo "ARCHITECT" ;;
            *) echo "UNKNOWN" ;;
        esac
    fi
}

# Format work item for display
format_work_item() {
    local work_item="$1"
    # Remove timestamp and tags
    echo "$work_item" | sed 's/.*WORK:PENDING\] //'
}

# Check safety limits - UPDATED to use es-projection.sh
check_safety_limits() {
    local persona="${1:-$(get_current_persona)}"
    
    # Check for too many activations
    local init_count=$(grep -c "\[${persona}:INIT\]\|TYPE:PERSONA_ACTIVATED.*PERSONA:$persona" "$JOURNAL_FILE" 2>/dev/null || echo "0")
    if [ $init_count -gt 10 ]; then
        echo -e "${RED}Safety Check Failed:${NC} Too many initializations ($init_count)"
        return 1
    fi
    
    return 0
}

# Common hook response
hook_success_response() {
    # Always exit 0 for hooks to allow execution
    exit 0
}

# Check if we're in a hook context
is_hook_context() {
    [ -n "$HOOK_TYPE" ] || [ -n "$JSON_INPUT" ]
}

# Safe hook exit (for use in hooks)
safe_hook_exit() {
    local exit_code="${1:-0}"
    local message="${2:-}"
    
    if [ -n "$message" ]; then
        if [ $exit_code -eq 0 ]; then
            echo "$message"
        else
            echo "$message" >&2
        fi
    fi
    
    exit $exit_code
}

# Get hook event name from JSON input
get_hook_event_name() {
    extract_json_field "$JSON_INPUT" '.hook_event_name'
}

# Check if this is a Stop event
is_stop_event() {
    [ "$(get_hook_event_name)" = "Stop" ] || [ "$(get_hook_event_name)" = "SubagentStop" ]
}

# Check if stop hook is already active (prevent recursion)
is_stop_hook_active() {
    local active=$(extract_json_field "$JSON_INPUT" '.stop_hook_active' 'false')
    [ "$active" = "true" ]
}

# Enhanced transition detection for autonomous workflow - UPDATED for pure event sourcing
detect_next_persona_automatically() {
    # Check each persona for pending work using es-projection.sh
    if command -v es-projection.sh >/dev/null 2>&1; then
        for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            local pending=$(es-projection.sh "$persona" "pending_work" | wc -l)
            if [ "$pending" -gt 0 ]; then
                echo "$persona"
                return 0
            fi
        done
    else
        # Fallback: Check for pending work across all personas
        for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            local pending=$(get_pending_count "$persona")
            if [ "$pending" -gt 0 ]; then
                echo "$persona"
                return 0
            fi
        done
    fi
    
    # No transition needed
    return 1
}

# Check for unprocessed handoffs
check_unprocessed_handoffs() {
    # Look for HANDOFF_READY events without subsequent PERSONA_ACTIVATED
    local last_handoff=$(grep "TYPE:HANDOFF_READY" "$JOURNAL_FILE" 2>/dev/null | tail -1)
    if [ -n "$last_handoff" ] && [[ "$last_handoff" =~ TO:([^|]+) ]]; then
        local to_persona="${BASH_REMATCH[1]}"
        local handoff_time=$(echo "$last_handoff" | cut -d' ' -f1)
        
        # Check if persona was activated after this handoff
        local activation=$(grep "TYPE:PERSONA_ACTIVATED.*PERSONA:$to_persona" "$JOURNAL_FILE" 2>/dev/null | tail -1)
        if [ -z "$activation" ]; then
            echo "$to_persona"
            return 0
        fi
        
        local activation_time=$(echo "$activation" | cut -d' ' -f1)
        if [[ "$handoff_time" > "$activation_time" ]]; then
            echo "$to_persona"
            return 0
        fi
    fi
    return 1
}

# Validate persona name
is_valid_persona() {
    local persona="$1"
    [[ "$persona" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]
}

# Get handoff processing status
get_handoff_status() {
    if command -v es-projection.sh >/dev/null 2>&1; then
        # Check if there are any unprocessed handoffs
        if check_unprocessed_handoffs >/dev/null 2>&1; then
            echo "pending"
        else
            echo "complete"
        fi
    else
        echo "unknown"
    fi
}

# Enhanced logging with transition events
log_transition_event() {
    local event_type="$1"
    local message="$2"
    log_event "TRANSITION:$event_type" "$message"
}

# Check if journal query system is available
is_enhanced_queries_available() {
    command -v es-projection.sh >/dev/null 2>&1
}

# Journal state validation
validate_journal_state() {
    if [ ! -f "$JOURNAL_FILE" ]; then
        echo "Journal file not found: $JOURNAL_FILE"
        return 1
    fi
    
    if [ ! -r "$JOURNAL_FILE" ]; then
        echo "Journal file not readable: $JOURNAL_FILE"
        return 1
    fi
    
    # Check for basic journal format
    if ! grep -q "Development Journal\|JOURNAL" "$JOURNAL_FILE" 2>/dev/null; then
        echo "Journal file format appears invalid"
        return 1
    fi
    
    return 0
}

# Enhanced debug information
debug_journal_state() {
    local persona="${1:-$(get_current_persona)}"
    
    echo "=== Journal State Debug ==="
    echo "Journal file: $JOURNAL_FILE"
    echo "Current persona: $persona"
    echo "Enhanced queries available: $(is_enhanced_queries_available && echo 'Yes' || echo 'No')"
    
    if command -v es-projection.sh >/dev/null 2>&1; then
        echo "Pending work count: $(get_pending_count "$persona")"
        echo "Handoff status: $(get_handoff_status)"
        echo "Current state: $(es-projection.sh "$persona" "current_state" 2>/dev/null || echo 'Unknown')"
    fi
    
    echo "Recent entries:"
    tail -5 "$JOURNAL_FILE" 2>/dev/null | sed 's/^/  /'
    echo "=========================="
}
