#!/bin/bash
# Simple card counter for specific states
# Usage: kanban-count-cards.sh [state]
# Returns just the count as a number

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"
STATE_FILTER="${1:-}"

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "0"
    exit 0
fi

# If no state specified, count all cards
if [ -z "$STATE_FILTER" ]; then
    kanban-state.sh --format json 2>/dev/null | jq 'length' 2>/dev/null || echo "0"
else
    # Count cards in specific state
    kanban-state.sh --state "$STATE_FILTER" --format json 2>/dev/null | jq 'length' 2>/dev/null || echo "0"
fi
