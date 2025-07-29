---
description: Display current Kanban board state with all cards
---

# Kanban Status

Display the current state of all Kanban cards in the autonomous development system.

## Usage

`/kanban-status`

Shows all cards organized by their current state.

## Process

I will:

1. Read `~/workspace/JOURNAL.md`
2. Parse all CARD_ events
3. Build current state for each card
4. Display organized by state

## Card States

- **BACKLOG** - Work not yet started
- **BREAKDOWN_STARTED** - Requirements analysis in progress
- **BREAKDOWN_ENDED** - Requirements complete, ready for development
- **IN_PROGRESS_STARTED** - Active development
- **IN_PROGRESS_ENDED** - Development complete, ready for validation
- **BLOCKED** - Waiting on dependencies
- **VALIDATION_STARTED** - Testing in progress
- **VALIDATION_ENDED** - Testing complete
- **DONE** - Work completed

## Output Format

```
=== Kanban Board Status ===

📋 BACKLOG (2)
├─ CARD-003: Implement user authentication
└─ CARD-004: Add logging system

🔍 BREAKDOWN_STARTED (1)
└─ CARD-005: Design API endpoints [Assigned: api-designer]

✅ BREAKDOWN_ENDED (1)
└─ CARD-001: Database schema [Ready for development]

🚧 IN_PROGRESS_STARTED (1)
└─ CARD-002: Create REST API [Assigned: feature-developer]

🏁 IN_PROGRESS_ENDED (0)

🚫 BLOCKED (1)
└─ CARD-006: Third-party integration [Blocker: API credentials needed]

🧪 VALIDATION_STARTED (1)
└─ CARD-007: User registration flow [Assigned: qa-engineer]

✓ VALIDATION_ENDED (0)

✨ DONE (2)
├─ CARD-008: Project setup
└─ CARD-009: CI/CD pipeline

=== Summary ===
Total Cards: 9
In Progress: 3
Blocked: 1
Completed: 2
```

## Additional Information

For each card, the display includes:
- Card ID
- Description
- Current assignee (if applicable)
- Blocker reason (if blocked)

This provides a complete view of project progress and helps identify bottlenecks.
