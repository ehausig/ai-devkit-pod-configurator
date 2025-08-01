#!/bin/bash
# Atomically try to assign a card to an agent
# Usage: kanban-try-assign-card.sh <card_id> <new_state> [target_state]
# Returns: 0 if successfully assigned, 1 if failed (someone else got it)
# Output: JSON with assignment result

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

if [ $# -lt 2 ]; then
    echo "Usage: kanban-try-assign-card.sh <card_id> <new_state> [target_state]"
    echo "Example: kanban-try-assign-card.sh CARD-001 breakdown_started backlog"
    exit 1
fi

CARD_ID="$1"
NEW_STATE="$2"
TARGET_STATE="${3:-}"  # Optional: expected current state

# Get the current agent using the getter script
AGENT=$(get-agent-name.sh)  # Will return "product-manager" by default

# Get current card state atomically
CURRENT_STATE=$(kanban-state.sh --card "$CARD_ID" --format json 2>/dev/null | jq -r '.[0] | {state: .state, assigned_to: .assigned_to, blocked: .blocked}')

if [ -z "$CURRENT_STATE" ] || [ "$CURRENT_STATE" = "null" ]; then
    echo '{"success": false, "reason": "Card not found", "card_id": "'$CARD_ID'"}'
    exit 1
fi

# Extract current values
CURRENT_STATE_NAME=$(echo "$CURRENT_STATE" | jq -r '.state')
CURRENT_ASSIGNED=$(echo "$CURRENT_STATE" | jq -r '.assigned_to // "null"')
CURRENT_BLOCKED=$(echo "$CURRENT_STATE" | jq -r '.blocked')

# Check if we can proceed with assignment
# Rules:
# 1. If TARGET_STATE specified, current state must match
# 2. Card must be unassigned OR assigned to us (for resuming blocked work)
# 3. If card is blocked, only the assigned agent can work on it

if [ -n "$TARGET_STATE" ] && [ "$CURRENT_STATE_NAME" != "$TARGET_STATE" ]; then
    echo '{"success": false, "reason": "Card state changed", "card_id": "'$CARD_ID'", "expected_state": "'$TARGET_STATE'", "actual_state": "'$CURRENT_STATE_NAME'"}'
    exit 1
fi

if [ "$CURRENT_ASSIGNED" != "null" ] && [ "$CURRENT_ASSIGNED" != "$AGENT" ]; then
    echo '{"success": false, "reason": "Card already assigned", "card_id": "'$CARD_ID'", "assigned_to": "'$CURRENT_ASSIGNED'"}'
    exit 1
fi

if [ "$CURRENT_BLOCKED" = "true" ] && [ "$CURRENT_ASSIGNED" != "$AGENT" ]; then
    echo '{"success": false, "reason": "Card is blocked and assigned to another agent", "card_id": "'$CARD_ID'", "assigned_to": "'$CURRENT_ASSIGNED'"}'
    exit 1
fi

# Generate a unique assignment ID to detect race conditions
ASSIGNMENT_ID=$(uuidgen 2>/dev/null || echo "${AGENT}-$$-$(date +%s)")

# Log the state change with assignment
journal-log-json.sh kanban card.state_changed "$CARD_ID" \
  --state "$NEW_STATE" \
  --assigned_to "$AGENT" \
  --previous_state "$CURRENT_STATE_NAME" \
  --assignment_id "$ASSIGNMENT_ID"

# Small delay to ensure journal write completes
sleep 0.2

# Verify we got the assignment by checking the last state change
VERIFICATION=$(cat "$JOURNAL_PATH" | jq -s "
    map(select(.card_id == \"$CARD_ID\" and .event_type == \"kanban.card.state_changed\")) |
    last |
    {
        assigned_to: .data.assigned_to,
        assignment_id: .data.assignment_id,
        state: .data.state
    }
")

VERIFIED_ASSIGNED=$(echo "$VERIFICATION" | jq -r '.assigned_to')
VERIFIED_ID=$(echo "$VERIFICATION" | jq -r '.assignment_id // ""')
VERIFIED_STATE=$(echo "$VERIFICATION" | jq -r '.state')

# Check if we successfully got the assignment
if [ "$VERIFIED_ASSIGNED" = "$AGENT" ] && [ "$VERIFIED_STATE" = "$NEW_STATE" ]; then
    # Extra check: if we have assignment IDs, verify it matches
    if [ -n "$ASSIGNMENT_ID" ] && [ -n "$VERIFIED_ID" ] && [ "$VERIFIED_ID" != "$ASSIGNMENT_ID" ]; then
        echo '{"success": false, "reason": "Lost assignment race", "card_id": "'$CARD_ID'", "assigned_to": "'$VERIFIED_ASSIGNED'"}'
        exit 1
    fi
    
    echo '{"success": true, "card_id": "'$CARD_ID'", "assigned_to": "'$AGENT'", "state": "'$NEW_STATE'"}'
    exit 0
else
    echo '{"success": false, "reason": "Failed to assign card", "card_id": "'$CARD_ID'", "assigned_to": "'$VERIFIED_ASSIGNED'"}'
    exit 1
fi
