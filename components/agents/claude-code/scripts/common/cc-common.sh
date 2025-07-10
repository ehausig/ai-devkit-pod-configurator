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
    es-journal-log.sh "$tag" "$message"
}

# Check if work item is completed
is_work_completed() {
    local work_desc="$1"
    grep -q "WORK:COMPLETED.*$work_desc" "$JOURNAL_FILE" 2>/dev/null
}

# Get pending work count for persona
get_pending_count() {
    local persona="${1:-$(get_current_persona)}"
    es-journal-query.sh pending-work "$persona" 2>/dev/null | wc -l
}

# Check if persona is ready for handoff
is_handoff_ready() {
    local persona="${1:-$(get_current_persona)}"
    local pending=$(get_pending_count "$persona")
    [ "$pending" -eq 0 ]
}

# Get next persona in workflow
get_next_persona() {
    local current="$1"
    case "$current" in
        ARCHITECT) echo "DEVELOPER" ;;
        DEVELOPER) 
            # Check if going to QA or back from review
            if es-journal-query.sh recent-context DEVELOPER | grep -q "changes requested"; then
                echo "QA"
            else
                echo "QA"
            fi
            ;;
        QA)
            # Check if tests passed
            local failed=$(es-journal-query.sh recent-context QA | grep -c "QA:FAILED" || echo "0")
            if [ $failed -eq 0 ]; then
                echo "REVIEWER"
            else
                echo "DEVELOPER"
            fi
            ;;
        REVIEWER)
            # Check if approved
            local issues=$(es-journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:ISSUE" || echo "0")
            if [ $issues -eq 0 ]; then
                echo "MERGER"
            else
                echo "DEVELOPER"
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
    local result=$(es-journal-query.sh safety-check "$persona")
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Safety Check Failed:${NC} $result"
        return 1
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
