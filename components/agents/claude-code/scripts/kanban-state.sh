#!/bin/bash
# Get current state of Kanban board by processing events
# Usage: kanban-state.sh [options]
# Options:
#   --card CARD-001     Show specific card state
#   --state work_started Show all cards in state
#   --assigned-to agent Show cards assigned to agent
#   --format json|table Output format (default: json)
#   --check-dependencies Include dependency status in output

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Default values
FORMAT="json"
CARD_FILTER=""
STATE_FILTER=""
ASSIGNED_FILTER=""
CHECK_DEPS=false

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
        --check-dependencies)
            CHECK_DEPS=true
            shift
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
            description: ($event.data.description // ""),
            state: ($event.data.state // "backlog"),
            dependencies: ($event.data.dependencies // []),
            assigned_to: ($event.data.assigned_to // null),
            notes: ($event.data.notes // ""),
            created_at: $event.timestamp,
            blocked: false,
            blocked_reason: null
        }
    elif $event.event_type == "kanban.card.state_changed" then
        if .[$event.card_id] then
            .[$event.card_id].state = $event.data.state |
            if $event.data.assigned_to != null then
                if $event.data.assigned_to == "null" then
                    .[$event.card_id].assigned_to = null
                else
                    .[$event.card_id].assigned_to = $event.data.assigned_to
                end
            end |
            if $event.data.previous_state then
                .[$event.card_id].previous_state = $event.data.previous_state
            end |
            if $event.data.notes then
                .[$event.card_id].notes = $event.data.notes
            end |
            if $event.data.blocked != null then
                .[$event.card_id].blocked = $event.data.blocked
            end |
            if $event.data.blocked_reason then
                .[$event.card_id].blocked_reason = $event.data.blocked_reason
            end
        else
            .
        end
    elif $event.event_type == "kanban.card.blocked" then
        if .[$event.card_id] then
            .[$event.card_id].previous_state = .[$event.card_id].state |
            .[$event.card_id].blocked = true |
            .[$event.card_id].blocked_reason = $event.data.reason |
            .[$event.card_id].state = "blocked"
        else
            .
        end
    elif $event.event_type == "kanban.card.unblocked" then
        if .[$event.card_id] then
            .[$event.card_id].blocked = false |
            .[$event.card_id].blocked_reason = null |
            # Restore previous state if available
            if .[$event.card_id].previous_state then
                .[$event.card_id].state = .[$event.card_id].previous_state
            else
                .
            end
        else
            .
        end
    elif $event.event_type == "kanban.card.assigned" then
        if .[$event.card_id] then
            .[$event.card_id].assigned_to = $event.data.to
        else
            .
        end
    # Handle old event types for backward compatibility
    elif $event.event_type == "kanban.card.breakdown.started" then
        if .[$event.card_id] then
            .[$event.card_id].state = "breakdown_started"
        else
            .
        end
    elif $event.event_type == "kanban.card.breakdown.ended" then
        if .[$event.card_id] then
            .[$event.card_id].state = "breakdown_ended"
        else
            .
        end
    elif $event.event_type == "kanban.card.work.started" then
        if .[$event.card_id] then
            .[$event.card_id].state = "work_started"
        else
            .
        end
    elif $event.event_type == "kanban.card.work.ended" then
        if .[$event.card_id] then
            .[$event.card_id].state = "work_ended"
        else
            .
        end
    elif $event.event_type == "kanban.card.validation.started" then
        if .[$event.card_id] then
            .[$event.card_id].state = "validation_started"
        else
            .
        end
    elif $event.event_type == "kanban.card.validation.ended" then
        if .[$event.card_id] then
            .[$event.card_id].state = "validation_ended"
        else
            .
        end
    elif $event.event_type == "kanban.card.completed" then
        if .[$event.card_id] then
            .[$event.card_id].state = "done"
        else
            .
        end
    else
        .
    end
) | to_entries | map(.value)'

# Apply dependency checking if requested
if [ "$CHECK_DEPS" = true ]; then
    JQ_QUERY="$JQ_QUERY"' | 
    # Add dependency status to each card
    . as $all_cards |
    map(. as $card |
        # Get list of completed cards
        ($all_cards | map(select(.state == "done") | .card_id)) as $completed |
        # Check if all dependencies are met
        $card + {
            dependencies_met: (
                $card.dependencies | length == 0 or
                all(. as $dep | $completed | contains([$dep]))
            ),
            unmet_dependencies: (
                $card.dependencies | map(select(. as $dep | $completed | contains([$dep]) | not))
            )
        }
    )'
fi

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
    
    if [ "$CHECK_DEPS" = true ]; then
        echo ""
        echo "DEPENDENCY STATUS:"
        echo "$RESULT" | jq -r '.[] | select(.dependencies | length > 0) | 
            "\(.card_id): \(if .dependencies_met then "✓ All dependencies met" else "✗ Waiting on: \(.unmet_dependencies | join(", "))" end)"'
    fi
else
    echo "$RESULT"
fi
