---
description: Add events to the development journal
---

# Event Emit

Add structured events to the development journal for debugging or manual intervention.

## Usage

`/event-emit <type> <persona> <description>`

## Process

I will:
1. Generate a UTC timestamp
2. Format the event with pipe delimiters
3. Append to `~/workspace/JOURNAL.md`
4. Confirm the event was added

## Event Types

Common types:
- `WORK_ASSIGNED` - Assign new work
- `WORK_COMPLETE` - Mark work done
- `DECISION` - Log a decision
- `HANDOFF` - Transfer between personas
- `FILE_CREATED` - New file created
- `TEST_RESULT` - Test outcome
- `ISSUE` - Problem found
- `NEXT_COMMAND` - Specify next command to execute
- `CYCLE_COMPLETE` - Mark development complete

## Examples

```
/event-emit WORK_ASSIGNED DEVELOPER "Fix review issue: Add input validation"
/event-emit DECISION ARCHITECT "Using PostgreSQL for data persistence"
/event-emit HANDOFF "DEVELOPER->QA" "Implementation complete"
/event-emit TEST_RESULT QA "Unit tests: 45 passed, 0 failed"
/event-emit NEXT_COMMAND SYSTEM "/developer"
/event-emit CYCLE_COMPLETE MERGER "v0.1.0 released"
```

## Format

Events are stored as:
```
TIMESTAMP | TYPE | PERSONA | DESCRIPTION
```

Example:
```
2024-01-15T10:00:00Z | WORK_ASSIGNED | DEVELOPER | Implement user authentication
2024-01-15T10:30:00Z | NEXT_COMMAND | DEVELOPER | /qa
```

## Special Event: NEXT_COMMAND

The `NEXT_COMMAND` event is used by the autonomous system to specify what command should be executed next. The orchestration hook reads this to continue the workflow:

```
2024-01-15T10:00:00Z | NEXT_COMMAND | ARCHITECT | /developer
2024-01-15T10:30:00Z | NEXT_COMMAND | QA | /reviewer
2024-01-15T11:00:00Z | NEXT_COMMAND | REVIEWER | /developer --fix-issues
```

## Notes

- This command is mainly for debugging or manual intervention
- The autonomous system normally manages events automatically
- Use UTC timestamps for consistency
- Ensure proper pipe delimiter spacing
- NEXT_COMMAND events drive the autonomous workflow

This allows manual event injection when needed for testing or correction.
