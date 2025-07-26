---
description: Query events from the development journal
---

# Event Query

Query and filter events from the development journal.

## Usage

`/event-query [persona] [type]`

- No arguments: Show recent 20 events
- Persona only: `/event-query DEVELOPER`
- Type only: `/event-query "" WORK_ASSIGNED`
- Both: `/event-query DEVELOPER WORK_COMPLETE`

## Process

I will:
1. Read `~/workspace/JOURNAL.md`
2. Filter based on criteria
3. Show matching events (last 20)
4. Display summary counts

## Filter Examples

Show all events:
```
/event-query
```

Show DEVELOPER's events:
```
/event-query DEVELOPER
```

Show all work assignments:
```
/event-query "" WORK_ASSIGNED
```

Show ARCHITECT's decisions:
```
/event-query ARCHITECT DECISION
```

## Query Patterns

Useful queries:
- Pending work: WORK_ASSIGNED without matching WORK_COMPLETE
- Handoff flow: All HANDOFF events
- Recent decisions: DECISION events
- Test results: TEST_RESULT events
- Issues found: QA_ISSUE or REVIEW_ISSUE

## Output Format

```
=== Event Query Results ===

2024-01-15T10:00:00Z | WORK_ASSIGNED | DEVELOPER | Implement core functionality
2024-01-15T10:30:00Z | WORK_STARTED | DEVELOPER | Implement core functionality
2024-01-15T11:00:00Z | WORK_COMPLETE | DEVELOPER | Implement core functionality

=== Summary ===
DEVELOPER total events: 15
WORK_ASSIGNED total: 5
```

## Advanced Patterns

To see pending work across all personas, I'll:
1. Count WORK_ASSIGNED events
2. Subtract WORK_COMPLETE events
3. Show the difference

This helps identify bottlenecks in the autonomous workflow.

This command provides visibility into the event-driven development process.
