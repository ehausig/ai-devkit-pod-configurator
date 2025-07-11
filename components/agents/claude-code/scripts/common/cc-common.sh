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

# Get current persona with fallback - UPDATED to use enhanced queries
get_current_persona() {
    local persona=$(es-journal-query.sh current-persona 2>/dev/null)
    if [ -z "$persona" ] || [ "$persona" = "UNKNOWN" ]; then
        # Try last-persona-init as fallback
        persona=$(es-journal-query.sh last-persona-init 2>/dev/null)
        if [ -z "$persona" ] || [ "$persona" = "UNKNOWN" ]; then
            # Final fallback to grep
            persona=$(grep "PERSONA:INIT" "$JOURNAL_FILE" 2>/dev/null | tail -1 | grep -o '\[.*:' | tr -d '[:[]' || echo "UNKNOWN")
        fi
    fi
    echo "$persona"
}

# Log with timestamp (wrapper around es-journal-log.sh)
log_event() {
    local tag="$1"
    local message="$2"
    
    # Ensure journal exists
    ensure_journal
    
    # Use es-journal-log.sh if available, otherwise write directly
    if command -v es-journal-log.sh >/dev/null 2>&1; then
        es-journal-log.sh "$tag" "$message"
    else
        echo "$(date -Iseconds) [$tag] $message" >> "$JOURNAL_FILE"
    fi
}

# Check if work item is completed
is_work_completed() {
    local work_desc="$1"
    grep -q "WORK:COMPLETED.*$work_desc" "$JOURNAL_FILE" 2>/dev/null
}

# Get pending work count for persona - UPDATED to use enhanced queries
get_pending_count() {
    local persona="${1:-$(get_current_persona)}"
    
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l
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

# Check if persona is ready for handoff - UPDATED to use enhanced queries
is_handoff_ready() {
    local persona="${1:-$(get_current_persona)}"
    
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        es-journal-query.sh handoff-ready "$persona" >/dev/null 2>&1
        return $?
    else
        # Fallback logic
        local pending=$(get_pending_count "$persona")
        [ "$pending" -eq 0 ]
    fi
}

# Get next persona in workflow - UPDATED to use enhanced queries
get_next_persona() {
    local current="$1"
    
    # Use centralized should-handoff query if available
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        local next_persona=$(es-journal-query.sh should-handoff "$current" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$next_persona" ]; then
            echo "$next_persona"
            return 0
        fi
    fi
    
    # Fallback to hardcoded logic (keep for compatibility)
    case "$current" in
        ARCHITECT) echo "DEVELOPER" ;;
        DEVELOPER) echo "QA" ;;
        QA)
            # Check if tests passed
            if command -v es-journal-query.sh >/dev/null 2>&1; then
                local failed=$(es-journal-query.sh recent-context QA | grep -c "QA:FAILED" || echo "0")
                if [ $failed -eq 0 ]; then
                    echo "REVIEWER"
                else
                    echo "DEVELOPER"
                fi
            else
                echo "REVIEWER"
            fi
            ;;
        REVIEWER)
            # Check if approved
            if command -v es-journal-query.sh >/dev/null 2>&1; then
                local issues=$(es-journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:ISSUE" || echo "0")
                if [ $issues -eq 0 ]; then
                    echo "MERGER"
                else
                    echo "DEVELOPER"
                fi
            else
                echo "MERGER"
            fi
            ;;
        MERGER) echo "ARCHITECT" ;; # Start new cycle
        *) echo "UNKNOWN" ;;
    esac
}

# Format work item for display
format_work_item() {
    local work_item="$1"
    # Remove timestamp and tags
    echo "$work_item" | sed 's/.*WORK:PENDING\] //'
}

# Check safety limits - UPDATED to use enhanced queries
check_safety_limits() {
    local persona="${1:-$(get_current_persona)}"
    
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        local result=$(es-journal-query.sh safety-check "$persona")
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo -e "${RED}Safety Check Failed:${NC} $result"
            return 1
        fi
    else
        # Fallback safety check
        local init_count=$(grep -c "\[${persona}:INIT\]" "$JOURNAL_FILE" 2>/dev/null || echo "0")
        if [ $init_count -gt 10 ]; then
            echo -e "${RED}Safety Check Failed:${NC} Too many initializations ($init_count)"
            return 1
        fi
    fi
    return 0
}

# REMOVED: signal_work_ready function (no longer needed with pure event sourcing)
# REMOVED: All file signaling functions

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
    # Use the new comprehensive transition-needed query
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        local next_persona=$(es-journal-query.sh transition-needed 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$next_persona" ]; then
            echo "$next_persona"
            return 0
        fi
    fi
    
    # Fallback: Check for pending work across all personas (deterministic order)
    for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
        local pending=$(get_pending_count "$persona")
        if [ "$pending" -gt 0 ]; then
            echo "$persona"
            return 0
        fi
    done
    
    # No transition needed
    return 1
}

# NEW: Check for unprocessed handoffs
check_unprocessed_handoffs() {
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        local unprocessed=$(es-journal-query.sh recent-handoff-unprocessed 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$unprocessed" ]; then
            echo "$unprocessed"
            return 0
        fi
    fi
    return 1
}

# NEW: Validate persona name
is_valid_persona() {
    local persona="$1"
    [[ "$persona" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]
}

# NEW: Get handoff processing status
get_handoff_status() {
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        es-journal-query.sh handoff-processing-complete 2>/dev/null
    else
        echo "unknown"
    fi
}

# NEW: Enhanced logging with transition events
log_transition_event() {
    local event_type="$1"
    local message="$2"
    log_event "TRANSITION:$event_type" "$message"
}

# NEW: Check if journal query system is available
is_enhanced_queries_available() {
    command -v es-journal-query.sh >/dev/null 2>&1 && \
    es-journal-query.sh recent-handoff-unprocessed >/dev/null 2>&1
    return $?
}

# NEW: Journal state validation
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

# NEW: Enhanced debug information
debug_journal_state() {
    local persona="${1:-$(get_current_persona)}"
    
    echo "=== Journal State Debug ==="
    echo "Journal file: $JOURNAL_FILE"
    echo "Current persona: $persona"
    echo "Enhanced queries available: $(is_enhanced_queries_available && echo 'Yes' || echo 'No')"
    
    if command -v es-journal-query.sh >/dev/null 2>&1; then
        echo "Pending work count: $(get_pending_count "$persona")"
        echo "Handoff status: $(get_handoff_status)"
        echo "Transition needed: $(es-journal-query.sh transition-needed 2>/dev/null || echo 'None')"
    fi
    
    echo "Recent entries:"
    tail -5 "$JOURNAL_FILE" 2>/dev/null | sed 's/^/  /'
    echo "=========================="
}
