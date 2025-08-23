#!/bin/bash
# Get complete timeline for a card
# Usage: card-timeline.sh <card_id> [options]
# Options:
#   --show-agents         Include agent activities
#   --show-tests         Include test results
#   --format json|timeline  Output format

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

if [ $# -lt 1 ]; then
    echo "Usage: card-timeline.sh <card_id> [options]"
    exit 1
fi

CARD_ID="$1"
shift

# Default values
SHOW_AGENTS=false
SHOW_TESTS=false
FORMAT="json"

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --show-agents)
            SHOW_AGENTS=true
            shift
            ;;
        --show-tests)
            SHOW_TESTS=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
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
JQ_FILTER="select(.card_id == \"$CARD_ID\" or .data.card_id == \"$CARD_ID\")"

# Filter event types based on options
EVENT_FILTER="kanban\."
if [ "$SHOW_AGENTS" = true ]; then
    EVENT_FILTER="${EVENT_FILTER}|agent\."
fi
if [ "$SHOW_TESTS" = true ]; then
    EVENT_FILTER="${EVENT_FILTER}|test\."
fi

JQ_FILTER="$JQ_FILTER | select(.event_type | test(\"$EVENT_FILTER\"))"

# Execute query and format output
if [ "$FORMAT" = "timeline" ]; then
    echo "=== Timeline for $CARD_ID ==="
    echo ""
    cat "$JOURNAL_PATH" | jq -r "$JQ_FILTER | \"[\(.timestamp)] \(.event_type) - \(.actor) - \(.data | tostring)\""
else
    cat "$JOURNAL_PATH" | jq -c "$JQ_FILTER"
fi
