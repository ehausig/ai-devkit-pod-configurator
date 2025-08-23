#!/bin/bash
# Get test execution results
# Usage: test-results.sh [options]
# Options:
#   --latest             Show only latest run
#   --card CARD-001      Filter by card
#   --failed-only        Show only failed tests
#   --coverage           Include coverage metrics

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Default values
LATEST=false
CARD_FILTER=""
FAILED_ONLY=false
INCLUDE_COVERAGE=false

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --latest)
            LATEST=true
            shift
            ;;
        --card)
            CARD_FILTER="$2"
            shift 2
            ;;
        --failed-only)
            FAILED_ONLY=true
            shift
            ;;
        --coverage)
            INCLUDE_COVERAGE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    if [ "$LATEST" = true ]; then
        echo "null"
    else
        echo "[]"
    fi
    exit 0
fi

# Build jq filter
JQ_FILTER="select(.event_type | startswith(\"test.\"))"

# Add card filter
if [ -n "$CARD_FILTER" ]; then
    JQ_FILTER="$JQ_FILTER | select(.data.card_id == \"$CARD_FILTER\")"
fi

# Filter for test execution events
if [ "$INCLUDE_COVERAGE" = false ]; then
    JQ_FILTER="$JQ_FILTER | select(.event_type | test(\"test.*executed|test.*passed|test.*failed\"))"
fi

# Filter for failed only
if [ "$FAILED_ONLY" = true ]; then
    JQ_FILTER="$JQ_FILTER | select(.event_type | endswith(\".failed\") or (.data.failed_tests > 0))"
fi

# Execute query
if [ "$LATEST" = true ]; then
    cat "$JOURNAL_PATH" | jq -s "map($JQ_FILTER) | last"
else
    cat "$JOURNAL_PATH" | jq -c "$JQ_FILTER"
fi
