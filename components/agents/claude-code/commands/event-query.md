---
description: Query events from the development journal with Kanban card support
---

# Event Query

Query and filter events from the autonomous development journal, including Kanban card events.

## Usage

`/event-query [type]`

- No arguments: Show all recent events
- Type filter: `/event-query CARD_`
- Multiple types: `/event-query "CARD_CREATED|CARD_UPDATED"`

## Event Types

### Project Management
- `PROJECT_INIT` - Project initialization
- `USER_REQUEST` - User requirements

### Kanban Card Events
- `CARD_CREATED` - New card created
- `CARD_UPDATED` - Card state changed
- `CARD_BLOCKED` - Card blocked
- `CARD_COMPLETED` - Card finished

### Work Tracking
- `WORK_ASSIGNED` - Work assigned to team
- `AGENT_START` - Agent beginning work
- `WORK_PROGRESS` - Progress updates
- `WORK_SUMMARY` - Work completion
- `WORK_COMPLETE` - Task finished

### Technical Events
- `DECISION` - Technical decisions
- `FILE_CREATED` - Files created

### Quality Events
- `TEST_RESULT` - Test outcomes
- `QA_ISSUE` - Quality issues
- `QA_SUMMARY` - QA completion
- `SECURITY_FINDING` - Security issues
- `SECURITY_SUMMARY` - Security review
- `PERFORMANCE_METRIC` - Performance data
- `PERFORMANCE_SUMMARY` - Performance analysis

### Team Events
- `API_SUMMARY` - API design complete
- `DB_SUMMARY` - Database design complete
- `PLATFORM_SUMMARY` - Platform setup complete
- `INTEGRATION_SUMMARY` - Integration complete
- `ALGORITHM_SUMMARY` - Algorithm implementation

### System Events
- `NEXT_AGENT` - Handoff directives (deprecated)
- `CYCLE_COMPLETE` - Development finished

## Process

I will:
1. Read `~/workspace/JOURNAL.md`
2. Filter based on criteria
3. Show matching events
4. Provide summary statistics

## Example Queries

Show all card events:
```
/event-query "CARD_"
```

Show work assignments:
```
/event-query WORK_ASSIGNED
```

Show technical decisions:
```
/event-query DECISION
```

Show quality events:
```
/event-query "QA_|SECURITY_|PERFORMANCE_"
```

Show team summaries:
```
/event-query "_SUMMARY"
```

## Output Format

```
=== Event Query Results ===

2024-01-20T10:00:00Z | CARD_CREATED | PM | CARD-001 | Setup development environment | BACKLOG
2024-01-20T10:00:00Z | CARD_CREATED | PM | CARD-002 | Design API specification | BACKLOG
2024-01-20T10:05:00Z | CARD_UPDATED | PM | CARD-001 | BACKLOG -> IN_PROGRESS_STARTED | Assigned: platform-engineer
2024-01-20T10:20:00Z | CARD_UPDATED | platform-engineer | CARD-001 | IN_PROGRESS_ENDED | Platform setup complete

=== Summary ===
Total CARD_ events: 4
- CARD_CREATED: 2
- CARD_UPDATED: 2
Agents involved: PM, platform-engineer
```

## Card State Analysis

When querying card events, the system also provides:
- Current state of each card
- State transition history
- Time spent in each state
- Assignment history

This helps track the flow of work through the Kanban system and identify bottlenecks.
