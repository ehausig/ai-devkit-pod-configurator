---
description: Query events from the development journal with Kanban card support
---

# Event Query

Query and filter events from the autonomous development journal using the new JSON format.

## Usage

`/event-query [pattern]`

- No arguments: Show all recent events
- Pattern filter: `/event-query "kanban.*"`
- Multiple patterns: `/event-query "kanban.*|agent.*"`

## Event Types

### System Events (`system.*`)
- `system.project.initialized` - Project initialization
- `system.user.request` - User requirements
- `system.project.completed` - Project completion
- `system.cycle.started` - Development cycle start
- `system.cycle.completed` - Development cycle end
- `system.context.compacted` - Context window compacted
- `system.error.critical` - Critical system error

### Kanban Events (`kanban.*`)
- `kanban.card.created` - New card created
- `kanban.card.breakdown.started` - Breakdown phase started
- `kanban.card.breakdown.ended` - Breakdown phase ended
- `kanban.card.work.started` - Work started
- `kanban.card.work.ended` - Work ended
- `kanban.card.validation.started` - Validation started
- `kanban.card.validation.ended` - Validation ended
- `kanban.card.completed` - Card completed
- `kanban.card.blocked` - Card blocked
- `kanban.card.unblocked` - Card unblocked
- `kanban.card.assigned` - Card assigned

### Agent Events (`agent.*`)
- `agent.started` - Agent begins work
- `agent.decision_made` - Agent makes decision
- `agent.work_performed` - Agent completes work
- `agent.error_encountered` - Agent encounters error
- `agent.completed` - Agent finishes
- `agent.handoff` - Agent hands off work

### Test Events (`test.*`)
- `test.suite.executed` - Test suite run
- `test.coverage.measured` - Coverage calculated
- `test.quality.issue.found` - Quality issue found
- `test.security.scan.completed` - Security scan done
- `test.unit.passed` - Unit tests passed
- `test.unit.failed` - Unit tests failed
- `test.integration.passed` - Integration tests passed
- `test.integration.failed` - Integration tests failed

### Telemetry Events (`telemetry.*`)
- `telemetry.metric` - Performance metric
- `telemetry.span` - Execution span
- `telemetry.log` - Log entry

## Process

I will:
1. Read `~/workspace/JOURNAL.md`
2. Use `journal-query.sh` to filter events
3. Show matching events with statistics

## Example Queries

Show all kanban events:
```bash
/event-query "kanban.*"
```

Show agent work:
```bash
/event-query "agent.work_performed"
```

Show test results:
```bash
/event-query "test.*"
```

Show multiple event types:
```bash
/event-query "kanban.card.created|kanban.card.completed"
```

## Implementation

```bash
# Get the pattern (default to all events)
PATTERN="${1:-.*}"

# Use journal-query.sh to get events
export EVENTS=$(journal-query.sh "$PATTERN")

# Count events by type
export EVENT_COUNTS=$(echo "$EVENTS" | jq -s 'group_by(.event_type) | map({type: .[0].event_type, count: length}) | sort_by(.count) | reverse')

# Display results
echo "=== Event Query Results ==="
echo ""

# Show events
echo "$EVENTS" | jq -r '. | "[\(.timestamp)] \(.event_type) - \(.actor) - \(.card_id // .data // "")"'

echo ""
echo "=== Summary ==="
echo "$EVENT_COUNTS" | jq -r '.[] | "- \(.type): \(.count)"'

# Show unique actors
export ACTORS=$(echo "$EVENTS" | jq -s 'map(.actor) | unique | join(", ")')
echo "Actors involved: $ACTORS"
```

## Output Format

```
=== Event Query Results ===

[2024-01-20T10:00:00+00:00] kanban.card.created - PM - CARD-001
[2024-01-20T10:00:01+00:00] kanban.card.created - PM - CARD-002
[2024-01-20T10:05:00+00:00] kanban.card.breakdown.started - PM - CARD-001
[2024-01-20T10:05:01+00:00] kanban.card.assigned - PM - CARD-001
[2024-01-20T10:20:00+00:00] kanban.card.breakdown.ended - platform-engineer - CARD-001

=== Summary ===
- kanban.card.created: 2
- kanban.card.breakdown.started: 1
- kanban.card.breakdown.ended: 1
- kanban.card.assigned: 1
Actors involved: PM, platform-engineer
```

## Card State Analysis

When querying kanban events, the system also provides:
- Current state of each card
- State transition history
- Time spent in each state
- Assignment history

This helps track the flow of work through the Kanban system and identify bottlenecks.
