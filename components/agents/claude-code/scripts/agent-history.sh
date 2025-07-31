#!/bin/bash
# Get agent work history
# Usage: agent-history.sh <agent_id> [options]
# Options:
#   --card CARD-001        Filter by card
#   --session SESSION-ID   Filter by session
#   --include-decisions    Include decision events
#   --files-only          Only show file operations

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

if [ $# -lt 1 ]; then
    echo "Usage: agent-history.sh <agent_id> [options]"
    exit 1
fi

AGENT_ID="$1"
shift

# Default values
CARD_FILTER=""
SESSION_FILTER=""
INCLUDE_DECISIONS=false
FILES_ONLY=false

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --card)
            CARD_FILTER="$2"
            shift 2
            ;;
        --session)
            SESSION_FILTER="$2"
            shift 2
            ;;
        --include-decisions)
            INCLUDE_DECISIONS=true
            shift
            ;;
        --files-only)
            FILES_ONLY=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "[]"
    exit 0
fi

# Build jq filter
JQ_FILTER="select(.event_type | startswith(\"agent.\")) | select(.agent_id == \"$AGENT_ID\")"

# Add optional filters
if [ -n "$CARD_FILTER" ]; then
    JQ_FILTER="$JQ_FILTER | select(.data.card_id == \"$CARD_FILTER\")"
fi

if [ -n "$SESSION_FILTER" ]; then
    JQ_FILTER="$JQ_FILTER | select(.session_id == \"$SESSION_FILTER\")"
fi

if [ "$INCLUDE_DECISIONS" = false ]; then
    JQ_FILTER="$JQ_FILTER | select(.event_type != \"agent.decision_made\")"
fi

if [ "$FILES_ONLY" = true ]; then
    JQ_FILTER="$JQ_FILTER | select(.data.files_created or .data.files_modified) | {timestamp, files_created: .data.files_created, files_modified: .data.files_modified}"
fi

# Execute query
cat "$JOURNAL_PATH" | jq -c "$JQ_FILTER"
