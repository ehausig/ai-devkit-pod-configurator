---
description: Display current persona context and recent activities from journal
---

# Show Current Context

Display the current persona's context reconstructed from the journal.

## Usage

```
/show-context [lines]
```

Where `[lines]` is optional number of recent entries to show (default: 20)

## Instructions

1. Identify current persona from recent journal entries
2. Extract relevant context for that persona
3. Show:
   - Recent activities
   - Pending handoffs
   - Critical memories
   - Unresolved issues

## Example Commands

```bash
# Get current persona
grep "PERSONA:INIT" ~/workspace/JOURNAL.md | tail -1

# Show recent context for current persona
CURRENT_PERSONA=$(grep "PERSONA:INIT" ~/workspace/JOURNAL.md | tail -1 | grep -o '\[.*:' | tr -d '[:[]')
grep "\[$CURRENT_PERSONA:" ~/workspace/JOURNAL.md | tail -20

# Show all persistent memories
grep "PERSONA:MEMORY" ~/workspace/JOURNAL.md

# Show pending work
grep "HANDOFF.*$CURRENT_PERSONA" ~/workspace/JOURNAL.md | tail -10
```
