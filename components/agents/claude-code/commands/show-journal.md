---
description: Display recent journal entries with formatting
---

# Show Journal

Display recent entries from the development journal with visual formatting.

## Usage

`/show-journal [lines]`

- Default: Shows last 20 events
- Specify number: `/show-journal 50`
- Show all: `/show-journal all`

## Process

I will:

1. Read `~/workspace/JOURNAL.md`
2. Parse event entries
3. Format with emoji indicators
4. Show summary statistics
5. Display current development state

## Event Formatting

- 📋 **WORK_ASSIGNED** - New task assigned
- 🚀 **WORK_STARTED** - Work begun
- ✅ **WORK_COMPLETE** - Task finished
- 🤝 **HANDOFF** - Persona transition
- 🎯 **DECISION** - Technical choice
- 📄 **FILE_CREATED** - New file
- 🧪 **TEST_RESULT** - Test outcome
- ⚠️ **ISSUE** - Problem found
- 🏁 **PROJECT_INIT** - Project started
- 🎉 **CYCLE_COMPLETE** - Development done

## Statistics Shown

- Total events logged
- Events per persona
- Current active persona
- Pending work items
- Development phase

## Time Display

- Today's events: Show time only
- Older events: Show full timestamp

## Example Output

```
=== Development Journal ===

[10:15:32] 📋 ARCHITECT: Design hello world system
[10:20:45] 🎯 ARCHITECT: Chose Python with Flask framework
[10:25:10] 📄 ARCHITECT: ARCHITECTURE.md
[10:30:00] ✅ ARCHITECT: Architecture phase complete
[10:30:01] 🤝 ARCHITECT->DEVELOPER: 5 tasks assigned

=== Journal Statistics ===
Total events: 12
ARCHITECT: 5 events
DEVELOPER: 7 events

=== Current State ===
Active persona: DEVELOPER (3 pending tasks)
Status: Development in progress...
```

This provides a clear visual overview of the autonomous development progress.
