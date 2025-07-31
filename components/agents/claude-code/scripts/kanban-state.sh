#!/bin/bash
# Get current state of Kanban board by processing events
# Usage: kanban-state.sh [options]
# Options:
#   --card CARD-001     Show specific card state
#   --state work_started Show all cards in state
#   --assigned-to agent Show cards assigned to agent
#   --format json|table Output format (default: json)

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Default values
FORMAT="json"
CARD_FILTER=""
STATE_FILTER=""
ASSIGNED_FILTER=""

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --card)
            CARD_FILTER="$2"
            shift 2
            ;;
        --state)
            STATE_FILTER="$2"
            shift 2
            ;;
        --assigned-to)
            ASSIGNED_FILTER="$2"
            shift 2
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
    if [ "$FORMAT" = "json" ]; then
        echo "[]"
    else
        echo "No journal found"
    fi
    exit 0
fi

# Build jq query to reconstruct board state
JQ_QUERY='
# Process all events to build current state
reduce .[] as $event ({};
    if $event.event_type == "kanban.card.created" then
        .[$event.card_id] = {
            card_id: $event.card_id,
            title: $event.data.title,
            state: "backlog",
            created_at: $event.timestamp,
            assigned_to: null,
            blocked: false,
            blocked_reason: null
        }
    elif $event.event_type == "kanban.card.breakdown.started" then
        .[$event.card_id].state = "breakdown_started"
    elif $event.event_type == "kanban.card.breakdown.ended" then
        .[$event.card_id].state = "breakdown_ended"
    elif $event.event_type == "kanban.card.work.started" then
        .[$event.card_id].state = "work_started"
    elif $event.event_type == "kanban.card.work.ended" then
        .[$event.card_id].state = "work_ended"
    elif $event.event_type == "kanban.card.validation.started" then
        .[$event.card_id].state = "validation_started"
    elif $event.event_type == "kanban.card.validation.ended" then
        .[$event.card_id].state = "validation_ended"
    elif $event.event_type == "kanban.card.completed" then
        .[$event.card_id].state = "done"
    elif $event.event_type == "kanban.card.blocked" then
        .[$event.card_id].blocked = true |
        .[$event.card_id].blocked_reason = $event.data.reason
    elif $event.event_type == "kanban.card.unblocked" then
        .[$event.card_id].blocked = false |
        .[$event.card_id].blocked_reason = null
    elif $event.event_type == "kanban.card.assigned" then
        .[$event.card_id].assigned_to = $event.data.assigned_to
    else
        .
    end
) | to_entries | map(.value)'

# Apply filters if specified
if [ -n "$CARD_FILTER" ]; then
    JQ_QUERY="$JQ_QUERY | map(select(.card_id == \"$CARD_FILTER\"))"
fi

if [ -n "$STATE_FILTER" ]; then
    JQ_QUERY="$JQ_QUERY | map(select(.state == \"$STATE_FILTER\"))"
fi

if [ -n "$ASSIGNED_FILTER" ]; then
    JQ_QUERY="$JQ_QUERY | map(select(.assigned_to == \"$ASSIGNED_FILTER\"))"
fi

# Execute query and format output
RESULT=$(cat "$JOURNAL_PATH" | jq -s "$JQ_QUERY")

if [ "$FORMAT" = "table" ]; then
    echo "CARD ID  | STATE              | ASSIGNED TO        | BLOCKED | TITLE"
    echo "---------|--------------------|--------------------|---------|------"
    echo "$RESULT" | jq -r '.[] | [.card_id, .state, .assigned_to // "unassigned", if .blocked then "YES" else "NO" end, .title] | @tsv' | \
    while IFS=$'\t' read -r card state assigned blocked title; do
        printf "%-8s | %-18s | %-18s | %-7s | %s\n" "$card" "$state" "$assigned" "$blocked" "$title"
    done
else
    echo "$RESULT"
fi
