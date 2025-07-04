---
description: Check the current work queue status for a persona
---

# Work Status

Display the current work queue status, pending items, and next actions.

## Usage

```
/work-status [persona]
```

Where `[persona]` is optional (defaults to current persona).

## Instructions

1. Check pending work count
2. Show recently completed work
3. Verify if work script is ready
4. Display next recommended actions

## Example Commands

```bash
# Check current persona's work status
work-status.sh

# Check specific persona's work status
work-status.sh DEVELOPER

# Alternative: Use the script directly
/usr/local/bin/work-status.sh
```

## Output Includes

- Current persona
- Pending work items count
- Recently completed items
- Work script ready status
- List of pending work
- Blocked work items (if any)
- Suggested next actions

## Related Commands

- `/execute-work` - Execute prepared work
- `/switch-persona` - Change active persona
- `/journal-summary` - Overall system status
