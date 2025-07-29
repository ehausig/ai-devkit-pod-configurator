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
2. Parse entries and format them
3. Track Kanban card states
4. Display agent progress and handoffs

## Event Formatting

### Project Events
- 📋 **PROJECT_INIT** - Project started
- 👤 **USER_REQUEST** - Initial requirements

### Card Events
- 🎫 **CARD_CREATED** - New Kanban card
- 🔄 **CARD_UPDATED** - Card state change
- 🚫 **CARD_BLOCKED** - Card blocked
- ✅ **CARD_COMPLETED** - Card done

### Work Events
- 📋 **WORK_ASSIGNED** - Task assigned to agent
- 🚀 **AGENT_START** - Agent began work
- 📊 **WORK_PROGRESS** - Progress update
- 📝 **WORK_SUMMARY** - Work completion summary

### Technical Events
- 🎯 **DECISION** - Technical choice made
- 📄 **FILE_CREATED** - New file created
- 🔧 **WORK_COMPLETE** - Task finished

### Quality Events
- 🧪 **TEST_RESULT** - Test execution results
- 🔍 **QA_ISSUE** - Quality issue found
- 🛡️ **SECURITY_FINDING** - Security issue
- ⚡ **PERFORMANCE_METRIC** - Performance data

### Team Events
- 🤝 **NEXT_AGENT** - Handoff directive (deprecated)
- 🎉 **CYCLE_COMPLETE** - Development done

## Example Output

```
=== Autonomous Development Journal ===

[10:00:00] 📋 PROJECT_INIT by PM: Starting project from PROMPT.md
[10:00:01] 👤 USER_REQUEST by PM: See PROMPT.md for full requirements
[10:00:02] 🎫 CARD_CREATED by PM: CARD-001 | Setup development environment | BACKLOG
[10:00:03] 🎫 CARD_CREATED by PM: CARD-002 | Design API specification | BACKLOG
[10:00:04] 🎫 CARD_CREATED by PM: CARD-003 | Implement user authentication | BACKLOG

[10:05:00] 🔄 CARD_UPDATED by PM: CARD-001 | BACKLOG -> IN_PROGRESS_STARTED | Assigned: platform-engineer
[10:05:01] 🚀 AGENT_START by platform-engineer: Beginning platform setup
[10:10:00] 📊 WORK_PROGRESS by platform-engineer: CARD-001 | Initialized Node.js project
[10:15:00] 📄 FILE_CREATED by platform-engineer: package.json
[10:20:00] 🔄 CARD_UPDATED by platform-engineer: CARD-001 | IN_PROGRESS_ENDED | Platform setup complete

[10:25:00] 🔄 CARD_UPDATED by PM: CARD-002 | BACKLOG -> BREAKDOWN_STARTED | Assigned: api-designer
[10:25:01] 🚀 AGENT_START by api-designer: Beginning API design
[10:30:00] 🎯 DECISION by api-designer: Using REST over GraphQL for simplicity
[10:35:00] 📄 FILE_CREATED by api-designer: openapi.yaml
[10:40:00] 🔄 CARD_UPDATED by api-designer: CARD-002 | BREAKDOWN_ENDED | API design complete

[10:45:00] 🔄 CARD_UPDATED by PM: CARD-003 | BACKLOG -> IN_PROGRESS_STARTED | Assigned: feature-developer
[10:45:01] 🚀 AGENT_START by feature-developer: Beginning implementation
[10:50:00] 📊 WORK_PROGRESS by feature-developer: CARD-003 | Implemented user model
[10:55:00] 🧪 TEST_RESULT by feature-developer: CARD-003 | Unit tests: 15 passed, 0 failed

=== Current Card Status ===
✅ DONE: CARD-001 (Setup development environment)
📝 BREAKDOWN_ENDED: CARD-002 (Design API specification)
🚧 IN_PROGRESS: CARD-003 (Implement user authentication)

=== Active Agent ===
Currently working: feature-developer on CARD-003
```

## Card State Summary

The journal viewer also tracks current card states:
- Cards in each state
- Currently assigned agents
- Blocked cards with reasons
- Overall progress metrics

This provides complete visibility into the autonomous development progress with Team Topologies organization.
