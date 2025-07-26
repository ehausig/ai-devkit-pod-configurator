---
description: Query events from the development journal
---

# Event Query

Query and filter events from the autonomous development journal.

## Usage

`/event-query [type]`

- No arguments: Show all recent events
- Type filter: `/event-query WORK_ASSIGNED`
- Multiple types: `/event-query "DECISION|FILE_CREATED"`

## Event Types

- `PROJECT_INIT` - Project initialization
- `WORK_ASSIGNED` - Task assignments
- `AGENT_START` - Agent beginning work
- `DECISION` - Technical decisions
- `FILE_CREATED` - Files created
- `NEXT_AGENT` - Handoff directives
- `WORK_COMPLETE` - Completed tasks
- `CYCLE_COMPLETE` - Development finished

## Process

I will:
1. Read `~/workspace/JOURNAL.md`
2. Filter based on criteria
3. Show matching events
4. Provide summary statistics

## Example Queries

Show all work assignments:
```
/event-query WORK_ASSIGNED
```

Show decisions and files:
```
/event-query "DECISION|FILE_CREATED"
```

Show handoff flow:
```
/event-query NEXT_AGENT
```

## Output Format

```
=== Event Query Results ===

2024-01-20T10:00:00Z | WORK_ASSIGNED | ARCHITECT | Design REST API
2024-01-20T11:00:00Z | WORK_ASSIGNED | DEVELOPER | Implement endpoints

=== Summary ===
Total WORK_ASSIGNED events: 2
Agents involved: ARCHITECT, DEVELOPER
```

This helps track specific aspects of the autonomous development process.
