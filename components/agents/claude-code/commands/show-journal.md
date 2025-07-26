---
description: Display development journal with formatted entries
---

# Show Journal

Display recent entries from the autonomous development journal.

## Usage

`/show-journal [lines]`

- Default: Shows last 30 events
- Specify number: `/show-journal 50`
- Show all: `/show-journal all`

## Process

I will:

1. Read `~/workspace/JOURNAL.md`
2. Parse entries and format them
3. Show current development state
4. Display agent progress

## Event Formatting

- 📋 **PROJECT_INIT** - Project started
- 📋 **WORK_ASSIGNED** - Task assigned to agent
- 🚀 **AGENT_START** - Agent began work
- 🎯 **DECISION** - Technical choice made
- 📄 **FILE_CREATED** - New file created
- 🤝 **NEXT_AGENT** - Handoff directive
- ✅ **WORK_COMPLETE** - Task finished
- 🎉 **CYCLE_COMPLETE** - Development done

## Example Output

```
=== Autonomous Development Journal ===

[10:00:00] 📋 PROJECT_INIT: Starting todo list API
[10:00:01] 📋 WORK_ASSIGNED to PRODUCT_MANAGER: Define requirements
[10:00:02] 🤝 NEXT_AGENT: system → product-manager
[10:15:00] 🚀 AGENT_START: product-manager reading assigned work
[10:20:00] 🎯 DECISION by product-manager: RESTful API with CRUD
[10:25:00] 📄 FILE_CREATED: REQUIREMENTS.md
[10:30:00] 🤝 NEXT_AGENT: product-manager → architect

=== Current Status ===
Active Flow: product-manager → architect
Next Agent: architect (pending delegation)
Files Created: 1
Decisions Made: 1
```

This provides visibility into the autonomous development progress.
