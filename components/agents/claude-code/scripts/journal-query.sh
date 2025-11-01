#!/bin/bash
# General purpose journal event querying
# Usage: journal-query.sh <event_pattern> [filters...]
# Examples:
#   journal-query.sh "kanban.*"                              # All kanban events
#   journal-query.sh "agent.*" --agent "platform-engineer"   # Events for specific agent
#   journal-query.sh "test.*" --after "2024-01-01"          # Test events after date

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "[]"
    exit 0
fi

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: journal-query.sh <event_pattern> [filters...]"
    exit 1
fi

EVENT_PATTERN="$1"
shift

# Build jq filter
JQ_FILTER="select(.event_type | test(\"$EVENT_PATTERN\"))"

# Parse additional filters
while [ $# -gt 0 ]; do
    case "$1" in
        --agent)
            shift
            JQ_FILTER="$JQ_FILTER | select(.agent == \"$1\")"
            shift
            ;;
        --card)
            shift
            JQ_FILTER="$JQ_FILTER | select(.card_id == \"$1\")"
            shift
            ;;
        --after)
            shift
            JQ_FILTER="$JQ_FILTER | select(.timestamp > \"$1\")"
            shift
            ;;
        --before)
            shift
            JQ_FILTER="$JQ_FILTER | select(.timestamp < \"$1\")"
            shift
            ;;
        --latest)
            # Will apply at the end
            LATEST=true
            shift
            ;;
        --count-only)
            COUNT_ONLY=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Execute query
if [ "$COUNT_ONLY" = true ]; then
    cat "$JOURNAL_PATH" | jq -s "map($JQ_FILTER) | length"
elif [ "$LATEST" = true ]; then
    cat "$JOURNAL_PATH" | jq -s "map($JQ_FILTER) | last"
else
    cat "$JOURNAL_PATH" | jq -c "$JQ_FILTER"
fi
