#!/bin/bash
# Common functions and utilities for Claude Code scripts

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

# Get current persona with fallback
get_current_persona() {
    local persona=$(es-journal-query.sh current-persona 2>/dev/null)
    if [ -z "$persona" ] || [ "$persona" = "UNKNOWN" ]; then
        # Try to extract from recent init
        persona=$(grep "PERSONA:INIT" "$JOURNAL_FILE" 2>/dev/null | tail -1 | grep -o '\[.*:' | tr -d '[:[]' || echo "UNKNOWN")
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

# Get pending work count for persona
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

# Check if persona is ready for handoff
is_handoff_ready() {
    local persona="${1:-$(get_current_persona)}"
    local pending=$(get_pending_count "$persona")
    [ "$pending" -eq 0 ]
}

# Get next persona in workflow (now using centralized logic)
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
    
    # Fallback to hardcoded logic
    case "$current" in
        ARCHITECT) echo "DEVELOPER" ;;
        DEVELOPER) 
            # Check if going to QA or back from review
            if command -v es-journal-query.sh >/dev/null 2>&1; then
                if es-journal-query.sh recent-context DEVELOPER | grep -q "changes requested"; then
                    echo "QA"
                else
                    echo "QA"
                fi
            else
                echo "QA"
            fi
            ;;
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

# Check safety limits
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

# Signal work ready for persona
signal_work_ready() {
    local persona="$1"
    echo "$persona" > /tmp/persona-work-ready
    log_event "WORK:QUEUE" "Work signaled ready for $persona"
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

# Enhanced persona detection for autonomous workflow
detect_next_persona_automatically() {
    # Check explicit signal first
    if [ -f /tmp/persona-work-ready ]; then
        cat /tmp/persona-work-ready
        return 0
    fi
    
    # Use centralized should-handoff logic
    local current_persona=$(get_current_persona)
    if [ -n "$current_persona" ] && [ "$current_persona" != "UNKNOWN" ]; then
        local next_persona=$(es-journal-query.sh should-handoff "$current_persona" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$next_persona" ]; then
            echo "$next_persona"
            return 0
        fi
    fi
    
    # Fallback: Check for pending work across all personas
    for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
        local pending=$(get_pending_count "$persona")
        if [ "$pending" -gt 0 ]; then
            echo "$persona"
            return 0
        fi
    done
    
    # No pending work found
    return 1
}
