#!/bin/bash
# Query available cards for agents to pull
# Usage: kanban-get-available-cards.sh [options]
# Options:
#   --state STATE           Filter by specific state
#   --for-agent-type TYPE   Get cards suitable for a specific agent type
#   --ready-only           Only show cards not blocked by dependencies
#   --unassigned-only      Only show cards not currently assigned

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Default values
STATE_FILTER=""
AGENT_TYPE=""
READY_ONLY=false
UNASSIGNED_ONLY=false

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --state)
            STATE_FILTER="$2"
            shift 2
            ;;
        --for-agent-type)
            AGENT_TYPE="$2"
            shift 2
            ;;
        --ready-only)
            READY_ONLY=true
            shift
            ;;
        --unassigned-only)
            UNASSIGNED_ONLY=true
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

# Define which agent types can work on which states
get_valid_states_for_agent() {
    local agent_type="$1"
    
    case "$agent_type" in
        "platform-engineer")
            echo '["backlog", "blocked"]'
            ;;
        "api-designer")
            echo '["backlog", "blocked"]'
            ;;
        "database-engineer")
            echo '["backlog", "blocked"]'
            ;;
        "solution-architect")
            echo '["backlog", "blocked"]'
            ;;
        "cloud-architect")
            echo '["backlog", "blocked"]'
            ;;
        "data-architect")
            echo '["backlog", "blocked"]'
            ;;
        "feature-developer")
            echo '["breakdown_ended", "blocked"]'
            ;;
        "algorithm-developer")
            echo '["breakdown_ended", "blocked"]'
            ;;
        "integration-specialist")
            echo '["breakdown_ended", "blocked"]'
            ;;
        "qa-engineer")
            echo '["work_ended", "blocked"]'
            ;;
        "security-specialist")
            echo '["work_ended", "validation_started", "blocked"]'
            ;;
        "performance-engineer")
            echo '["work_ended", "validation_started", "blocked"]'
            ;;
        *)
            # Unknown agent type can't pull any cards
            echo '[]'
            ;;
    esac
}

# Build jq query to get current board state
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
            if $event.data.assigned_to then
                .[$event.card_id].assigned_to = $event.data.assigned_to
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
        end
    elif $event.event_type == "kanban.card.blocked" then
        if .[$event.card_id] then
            .[$event.card_id].blocked = true |
            .[$event.card_id].blocked_reason = $event.data.reason
        end
    elif $event.event_type == "kanban.card.unblocked" then
        if .[$event.card_id] then
            .[$event.card_id].blocked = false |
            .[$event.card_id].blocked_reason = null
        end
    elif $event.event_type == "kanban.card.assigned" then
        if .[$event.card_id] then
            .[$event.card_id].assigned_to = $event.data.to
        end
    # Handle old event types for backward compatibility
    elif $event.event_type == "kanban.card.breakdown.started" then
        if .[$event.card_id] then
            .[$event.card_id].state = "breakdown_started"
        end
    elif $event.event_type == "kanban.card.breakdown.ended" then
        if .[$event.card_id] then
            .[$event.card_id].state = "breakdown_ended"
        end
    elif $event.event_type == "kanban.card.work.started" then
        if .[$event.card_id] then
            .[$event.card_id].state = "work_started"
        end
    elif $event.event_type == "kanban.card.work.ended" then
        if .[$event.card_id] then
            .[$event.card_id].state = "work_ended"
        end
    elif $event.event_type == "kanban.card.validation.started" then
        if .[$event.card_id] then
            .[$event.card_id].state = "validation_started"
        end
    elif $event.event_type == "kanban.card.validation.ended" then
        if .[$event.card_id] then
            .[$event.card_id].state = "validation_ended"
        end
    elif $event.event_type == "kanban.card.completed" then
        if .[$event.card_id] then
            .[$event.card_id].state = "done"
        end
    else
        .
    end
) | to_entries | map(.value)'

# Get all cards and their current state
ALL_CARDS=$(cat "$JOURNAL_PATH" | jq -s "$JQ_QUERY")

# Apply filters
if [ -n "$STATE_FILTER" ]; then
    ALL_CARDS=$(echo "$ALL_CARDS" | jq "map(select(.state == \"$STATE_FILTER\"))")
fi

if [ "$UNASSIGNED_ONLY" = true ]; then
    ALL_CARDS=$(echo "$ALL_CARDS" | jq 'map(select(.assigned_to == null))')
fi

# Filter by agent type capabilities
if [ -n "$AGENT_TYPE" ]; then
    VALID_STATES=$(get_valid_states_for_agent "$AGENT_TYPE")
    ALL_CARDS=$(echo "$ALL_CARDS" | jq --argjson states "$VALID_STATES" 'map(select(.state as $s | $states | contains([$s])))')
fi

# If ready-only, check dependencies AND handle blocked cards
if [ "$READY_ONLY" = true ]; then
    # Get list of completed cards
    COMPLETED_CARDS=$(echo "$ALL_CARDS" | jq '[.[] | select(.state == "done") | .card_id]')
    
    # Filter cards: either not blocked OR blocked but assigned to requesting agent
    if [ -n "$AGENT_TYPE" ]; then
        ALL_CARDS=$(echo "$ALL_CARDS" | jq --argjson completed "$COMPLETED_CARDS" --arg agent "$AGENT_TYPE" '
            map(select(
                # Not already done
                .state != "done" and
                # Either not blocked OR (blocked AND assigned to this agent type)
                (.blocked != true or (.blocked == true and .assigned_to == $agent)) and
                # All dependencies are completed
                (.dependencies | length == 0 or 
                 all(. as $dep | $completed | contains([$dep])))
            ))
        ')
    else
        ALL_CARDS=$(echo "$ALL_CARDS" | jq --argjson completed "$COMPLETED_CARDS" '
            map(select(
                # Not already done
                .state != "done" and
                # Not explicitly blocked (when no agent type specified)
                .blocked != true and
                # All dependencies are completed
                (.dependencies | length == 0 or 
                 all(. as $dep | $completed | contains([$dep])))
            ))
        ')
    fi
fi

# Sort by creation time (oldest first for FIFO)
ALL_CARDS=$(echo "$ALL_CARDS" | jq 'sort_by(.created_at)')

# Output the filtered cards
echo "$ALL_CARDS"
