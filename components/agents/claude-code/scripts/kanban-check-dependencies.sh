#!/bin/bash
# Check if a card's dependencies are met
# Usage: kanban-check-dependencies.sh <card_id>
# Returns: 0 if dependencies are met, 1 if not met
# Output: JSON with dependency status

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

if [ $# -lt 1 ]; then
    echo "Usage: kanban-check-dependencies.sh <card_id>"
    exit 1
fi

CARD_ID="$1"

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo '{"card_id": "'$CARD_ID'", "dependencies_met": true, "unmet_dependencies": [], "message": "No journal found"}'
    exit 0
fi

# Get current board state and check dependencies
RESULT=$(cat "$JOURNAL_PATH" | jq -s "
# First, build the current board state
(reduce .[] as \$event ({};
    if \$event.event_type == \"kanban.card.created\" then
        .[\$event.card_id] = {
            card_id: \$event.card_id,
            state: (\$event.data.state // \"backlog\"),
            dependencies: (\$event.data.dependencies // [])
        }
    elif \$event.event_type == \"kanban.card.state_changed\" then
        if .[\$event.card_id] then
            .[\$event.card_id].state = \$event.data.state
        else
            .
        end
    elif \$event.event_type == \"kanban.card.completed\" then
        if .[\$event.card_id] then
            .[\$event.card_id].state = \"done\"
        else
            .
        end
    # Handle old event types
    elif \$event.event_type | test(\"kanban\\\\.card\\\\..*\\\\.started|kanban\\\\.card\\\\..*\\\\.ended\") then
        if .[\$event.card_id] then
            if \$event.event_type == \"kanban.card.breakdown.started\" then
                .[\$event.card_id].state = \"breakdown_started\"
            elif \$event.event_type == \"kanban.card.breakdown.ended\" then
                .[\$event.card_id].state = \"breakdown_ended\"
            elif \$event.event_type == \"kanban.card.work.started\" then
                .[\$event.card_id].state = \"work_started\"
            elif \$event.event_type == \"kanban.card.work.ended\" then
                .[\$event.card_id].state = \"work_ended\"
            elif \$event.event_type == \"kanban.card.validation.started\" then
                .[\$event.card_id].state = \"validation_started\"
            elif \$event.event_type == \"kanban.card.validation.ended\" then
                .[\$event.card_id].state = \"validation_ended\"
            else
                .
            end
        else
            .
        end
    else
        .
    end
)) as \$board_state |

# Now check the specific card
if \$board_state[\"$CARD_ID\"] then
    \$board_state[\"$CARD_ID\"] as \$card |
    \$card.dependencies as \$deps |
    
    # Find which dependencies are not done
    [\$deps[] | select(\$board_state[.].state != \"done\")] as \$unmet |
    
    {
        card_id: \"$CARD_ID\",
        dependencies: \$deps,
        dependencies_met: (\$unmet | length == 0),
        unmet_dependencies: \$unmet,
        dependency_states: (\$deps | map({dep: ., state: \$board_state[.].state}))
    }
else
    {
        card_id: \"$CARD_ID\",
        dependencies_met: true,
        unmet_dependencies: [],
        message: \"Card not found\"
    }
end
")

echo "$RESULT"

# Exit with appropriate code
if echo "$RESULT" | jq -e '.dependencies_met' > /dev/null; then
    exit 0
else
    exit 1
fi
