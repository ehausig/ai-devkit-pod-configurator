#!/bin/bash
# Simple card status check - returns just the current state
# Usage: card-status.sh <card_id>

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

if [ $# -lt 1 ]; then
    echo "Usage: card-status.sh <card_id>"
    exit 1
fi

CARD_ID="$1"

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "unknown"
    exit 1
fi

# Get current state by finding the last state-changing event
STATE=$(cat "$JOURNAL_PATH" | jq -r "
    map(select(.card_id == \"$CARD_ID\" and (
        .event_type == \"kanban.card.created\" or
        .event_type == \"kanban.card.breakdown.started\" or
        .event_type == \"kanban.card.breakdown.ended\" or
        .event_type == \"kanban.card.work.started\" or
        .event_type == \"kanban.card.work.ended\" or
        .event_type == \"kanban.card.validation.started\" or
        .event_type == \"kanban.card.validation.ended\" or
        .event_type == \"kanban.card.completed\"
    ))) | 
    last | 
    if .event_type == \"kanban.card.created\" then \"backlog\"
    elif .event_type == \"kanban.card.breakdown.started\" then \"breakdown_started\"
    elif .event_type == \"kanban.card.breakdown.ended\" then \"breakdown_ended\"
    elif .event_type == \"kanban.card.work.started\" then \"work_started\"
    elif .event_type == \"kanban.card.work.ended\" then \"work_ended\"
    elif .event_type == \"kanban.card.validation.started\" then \"validation_started\"
    elif .event_type == \"kanban.card.validation.ended\" then \"validation_ended\"
    elif .event_type == \"kanban.card.completed\" then \"done\"
    else \"unknown\"
    end
")

# Handle null or empty result
if [ -z "$STATE" ] || [ "$STATE" = "null" ]; then
    echo "unknown"
else
    echo "$STATE"
fi
