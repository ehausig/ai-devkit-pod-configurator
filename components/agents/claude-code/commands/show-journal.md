---
description: Display development journal with formatted entries and Kanban card tracking
---

# Show Journal

Display recent entries from the autonomous development journal with enhanced formatting for Kanban cards.

## Usage

`/show-journal [lines]`

- Default: Shows last 30 events
- Specify number: `/show-journal 50`
- Show all: `/show-journal all`

## Process

I will:

1. Read `~/workspace/JOURNAL.md`
2. Parse JSON Lines entries
3. Format events for display
4. Show agent progress and handoffs

## Event Formatting

### System Events
- 📋 **system.project.initialized** - Project started
- 👤 **system.user.request** - Initial requirements
- 🎉 **system.project.completed** - Project finished

### Kanban Events
- 🎫 **kanban.card.created** - New Kanban card
- ▶️ **kanban.card.breakdown.started** - Breakdown phase began
- ✅ **kanban.card.breakdown.ended** - Breakdown complete
- 🔨 **kanban.card.work.started** - Work began
- 🏁 **kanban.card.work.ended** - Work complete
- 🧪 **kanban.card.validation.started** - Testing began
- ✓ **kanban.card.validation.ended** - Testing complete
- ✨ **kanban.card.completed** - Card done
- 🚫 **kanban.card.blocked** - Card blocked
- 🔓 **kanban.card.unblocked** - Card unblocked
- 👤 **kanban.card.assigned** - Card assigned

### Agent Events
- 🚀 **agent.started** - Agent began work
- 🎯 **agent.decision_made** - Decision recorded
- 📊 **agent.work_performed** - Work completed
- ⚠️ **agent.error_encountered** - Error occurred
- ✅ **agent.completed** - Agent finished
- 🤝 **agent.handoff** - Work handed off

### Test Events
- 🧪 **test.suite.executed** - Tests run
- 📊 **test.coverage.measured** - Coverage calculated
- 🔍 **test.quality.issue.found** - Issue detected
- 🛡️ **test.security.scan.completed** - Security scan done
- ✅ **test.unit.passed** - Unit tests passed
- ❌ **test.unit.failed** - Unit tests failed

### Telemetry Events
- 📈 **telemetry.metric** - Performance metric
- 🔄 **telemetry.span** - Execution span
- 📝 **telemetry.log** - Log entry

## Implementation

```bash
# Read journal and format output
if [ ! -f ~/workspace/JOURNAL.md ]; then
    echo "No journal found"
    exit 0
fi

# Determine number of lines to show
LINES="${1:-30}"

# Get events (all or last N)
if [ "$LINES" = "all" ]; then
    EVENTS=$(cat ~/workspace/JOURNAL.md)
else
    EVENTS=$(tail -n "$LINES" ~/workspace/JOURNAL.md)
fi

# Format and display events
echo "=== Autonomous Development Journal ==="
echo ""

# Process each JSON line
echo "$EVENTS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    # Parse JSON fields
    TIMESTAMP=$(echo "$line" | jq -r '.timestamp')
    EVENT_TYPE=$(echo "$line" | jq -r '.event_type')
    ACTOR=$(echo "$line" | jq -r '.actor')
    
    # Format timestamp to time only
    TIME=$(echo "$TIMESTAMP" | cut -d'T' -f2 | cut -d'+' -f1)
    
    # Get appropriate emoji
    case "$EVENT_TYPE" in
        system.project.initialized) EMOJI="📋" ;;
        kanban.card.created) EMOJI="🎫" ;;
        kanban.card.work.started) EMOJI="🔨" ;;
        agent.started) EMOJI="🚀" ;;
        test.suite.executed) EMOJI="🧪" ;;
        # ... etc
    esac
    
    # Build message based on event type
    case "$EVENT_TYPE" in
        kanban.card.*)
            CARD_ID=$(echo "$line" | jq -r '.card_id // ""')
            MESSAGE="$CARD_ID"
            
            # Add specific details
            case "$EVENT_TYPE" in
                kanban.card.created)
                    TITLE=$(echo "$line" | jq -r '.data.title // ""')
                    MESSAGE="$MESSAGE | $TITLE"
                    ;;
                kanban.card.assigned)
                    ASSIGNED_TO=$(echo "$line" | jq -r '.data.assigned_to // ""')
                    MESSAGE="$MESSAGE | Assigned to: $ASSIGNED_TO"
                    ;;
            esac
            ;;
        *)
            # Extract relevant data for other event types
            MESSAGE=$(echo "$line" | jq -r '.data | to_entries | map("\(.key): \(.value)") | join(", ")')
            ;;
    esac
    
    # Display formatted event
    printf "[%s] %s %s by %s: %s\n" "$TIME" "$EMOJI" "$EVENT_TYPE" "$ACTOR" "$MESSAGE"
done

# Show current card status summary
echo ""
echo "=== Current Card Status ==="
kanban-state.sh --format table
```

## Example Output

```
=== Autonomous Development Journal ===

[10:00:00] 📋 system.project.initialized by PM: project_name: Hello World Python, prompt_file: PROMPT.md
[10:00:01] 👤 system.user.request by PM: request: See PROMPT.md for full requirements
[10:00:02] 🎫 kanban.card.created by PM: CARD-001 | Setup development environment
[10:00:03] 🎫 kanban.card.created by PM: CARD-002 | Design API specification
[10:00:04] 🎫 kanban.card.created by PM: CARD-003 | Implement user authentication

[10:05:00] ▶️ kanban.card.breakdown.started by PM: CARD-001
[10:05:01] 👤 kanban.card.assigned by PM: CARD-001 | Assigned to: platform-engineer
[10:05:02] 🚀 agent.started by platform-engineer: card_id: CARD-001, context: Setting up Python project
[10:10:00] 📊 agent.work_performed by platform-engineer: work_description: Created pyproject.toml
[10:15:00] ✅ kanban.card.breakdown.ended by platform-engineer: CARD-001

=== Current Card Status ===
CARD ID  | STATE              | ASSIGNED TO        | BLOCKED | TITLE
---------|--------------------|--------------------|---------|------
CARD-001 | breakdown_ended    | platform-engineer  | NO      | Setup development environment
CARD-002 | backlog           | unassigned         | NO      | Design API specification
CARD-003 | backlog           | unassigned         | NO      | Implement user authentication
```

This provides complete visibility into the autonomous development progress with the new JSON event format.
