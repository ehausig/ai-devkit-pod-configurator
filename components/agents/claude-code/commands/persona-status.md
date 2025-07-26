---
description: Show current status of all personas
---

# Persona Status

Display the current status and workload of each persona in the autonomous system.

## Process

I will:

1. Read the journal at `~/workspace/JOURNAL.md`
2. Calculate status for each persona
3. Show pending work items
4. Display workflow state
5. Provide project metrics

## Status Indicators

- 🟡 **ACTIVE** - Has pending work
- 🟢 **COMPLETE** - All work finished  
- ⚪ **IDLE** - No work assigned

## Information Displayed

For each persona:
- Current status
- Work statistics (assigned/started/completed)
- Pending tasks list
- Last activity
- Handoff counts

## Workflow Summary

Shows:
- Current development phase
- Recent handoff flow
- Overall progress

## Project Metrics

Includes:
- Total decisions made
- Files created
- Test runs executed
- Issues discovered
- Current test coverage

## Example Output

```
=== Persona Status Dashboard ===

━━━ ARCHITECT ━━━
Status: 🟢 COMPLETE - All tasks finished
Tasks: 4 assigned, 4 started, 4 completed
Last activity: WORK_COMPLETE at 10:30:00Z
Handoffs: 0 received, 1 given

━━━ DEVELOPER ━━━
Status: 🟡 ACTIVE - 3 pending tasks
Tasks: 5 assigned, 2 started, 2 completed
Pending work:
  • Implement core functionality with TDD
  • Add error handling and logging
  • Ensure 80% test coverage
Last activity: WORK_COMPLETE at 11:45:30Z

━━━ QA ━━━
Status: ⚪ IDLE - No work assigned

=== Workflow Summary ===
Phase: DEVELOPER phase in progress
Handoff Flow:
  10:30:01: ARCHITECT->DEVELOPER

=== Project Metrics ===
Decisions made: 8
Files created: 4
Test runs: 2
Issues found: 0
Test coverage: 75%
```

This provides a comprehensive view of the autonomous system's current state.
