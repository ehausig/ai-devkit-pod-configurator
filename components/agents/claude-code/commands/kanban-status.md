---
description: Display current Kanban board state with all cards
---

# Kanban Status

Display the current state of all Kanban cards in the autonomous development system using the new JSON event format.

## Usage

`/kanban-status`

Shows all cards organized by their current state.

## Process

I will:

1. Use `kanban-state.sh` to get current board state
2. Group cards by state
3. Display in organized format

## Card States

- **backlog** - Work not yet started (created)
- **breakdown_started** - Requirements analysis in progress
- **breakdown_ended** - Requirements complete, ready for development
- **work_started** - Active development
- **work_ended** - Development complete, ready for validation
- **validation_started** - Testing in progress
- **validation_ended** - Testing complete
- **done** - Work completed

## Implementation

```bash
# Get current board state
export BOARD_STATE=$(kanban-state.sh --format json)

# Group by state
export BACKLOG=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "backlog")]')
export BREAKDOWN_STARTED=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "breakdown_started")]')
export BREAKDOWN_ENDED=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "breakdown_ended")]')
export WORK_STARTED=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "work_started")]')
export WORK_ENDED=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "work_ended")]')
export VALIDATION_STARTED=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "validation_started")]')
export VALIDATION_ENDED=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "validation_ended")]')
export DONE=$(echo "$BOARD_STATE" | jq '[.[] | select(.state == "done")]')
export BLOCKED=$(echo "$BOARD_STATE" | jq '[.[] | select(.blocked == true)]')

# Display formatted output
echo "=== Kanban Board Status ==="
echo ""

# Function to display cards in a state
display_state() {
    local STATE_NAME="$1"
    local CARDS="$2"
    local EMOJI="$3"
    
    local COUNT=$(echo "$CARDS" | jq 'length')
    echo "$EMOJI $STATE_NAME ($COUNT)"
    
    if [ "$COUNT" -gt 0 ]; then
        echo "$CARDS" | jq -r '.[] | "├─ \(.card_id): \(.title)\(if .assigned_to then " [Assigned: \(.assigned_to)]" else "" end)\(if .blocked then " [BLOCKED: \(.blocked_reason)]" else "" end)"'
    fi
    echo ""
}

# Display each state
display_state "BACKLOG" "$BACKLOG" "📋"
display_state "BREAKDOWN STARTED" "$BREAKDOWN_STARTED" "🔍"
display_state "BREAKDOWN ENDED" "$BREAKDOWN_ENDED" "✅"
display_state "WORK STARTED" "$WORK_STARTED" "🚧"
display_state "WORK ENDED" "$WORK_ENDED" "🏁"
display_state "VALIDATION STARTED" "$VALIDATION_STARTED" "🧪"
display_state "VALIDATION ENDED" "$VALIDATION_ENDED" "✓"
display_state "DONE" "$DONE" "✨"

# Show blocked cards separately if any
if [ $(echo "$BLOCKED" | jq 'length') -gt 0 ]; then
    echo "🚫 BLOCKED CARDS"
    echo "$BLOCKED" | jq -r '.[] | "├─ \(.card_id): \(.blocked_reason)"'
    echo ""
fi

# Summary
export TOTAL=$(echo "$BOARD_STATE" | jq 'length')
export IN_PROGRESS=$(echo "$BOARD_STATE" | jq '[.[] | select(.state | test("started$"))] | length')
export COMPLETED=$(echo "$DONE" | jq 'length')

echo "=== Summary ==="
echo "Total Cards: $TOTAL"
echo "In Progress: $IN_PROGRESS"
echo "Blocked: $(echo "$BLOCKED" | jq 'length')"
echo "Completed: $COMPLETED"
```

## Output Format

```
=== Kanban Board Status ===

📋 BACKLOG (2)
├─ CARD-003: Implement user authentication
├─ CARD-004: Add logging system

🔍 BREAKDOWN STARTED (1)
├─ CARD-005: Design API endpoints [Assigned: api-designer]

✅ BREAKDOWN ENDED (1)
├─ CARD-001: Database schema

🚧 WORK STARTED (1)
├─ CARD-002: Create REST API [Assigned: feature-developer]

🏁 WORK ENDED (0)

🧪 VALIDATION STARTED (1)
├─ CARD-007: User registration flow [Assigned: qa-engineer]

✓ VALIDATION ENDED (0)

✨ DONE (2)
├─ CARD-008: Project setup
├─ CARD-009: CI/CD pipeline

🚫 BLOCKED CARDS
├─ CARD-006: Waiting for API credentials

=== Summary ===
Total Cards: 9
In Progress: 3
Blocked: 1
Completed: 2
```

## Additional Information

For each card, the display includes:
- Card ID
- Title/Description
- Current assignee (if applicable)
- Blocker reason (if blocked)

This provides a complete view of project progress and helps identify bottlenecks in the development flow.
