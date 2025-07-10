---
description: Execute the next pending work item for the current persona
---

# Execute Work

Execute the next pending work item from the journal work queue.

## Usage

```
/execute-work [persona]
```

Where `[persona]` is optional (defaults to current persona).

## Instructions

1. Check for pending work items
2. If work script exists, execute it
3. If no work script, prepare one and execute
4. Show work progress and next steps

## Example Commands

```bash
# Check if work script already exists
if [ -f /tmp/execute-next-work.sh ]; then
    echo "Executing prepared work script..."
    /tmp/execute-next-work.sh
else
    echo "Preparing work script..."
    # Get current persona
    PERSONA=$(es-journal-query.sh current-persona)
    
    # Check for pending work
    PENDING=$(es-journal-query.sh pending-work $PERSONA | wc -l)
    
    if [ $PENDING -gt 0 ]; then
        # Prepare and execute work
        es-work-tracker.sh prepare $PERSONA
        
        if [ -f /tmp/execute-next-work.sh ]; then
            echo ""
            echo "Executing work..."
            /tmp/execute-next-work.sh
        else
            echo "Failed to prepare work script"
        fi
    else
        echo "No pending work for $PERSONA"
        echo ""
        echo "Options:"
        echo "1. Run handoff script if work is complete" 
        echo "2. Check work summary: es-journal-query.sh work-summary $PERSONA"
        echo "3. Switch persona: /switch-persona [persona]"
    fi
fi
```

## Work Flow

This command integrates with the event-driven work queue system:

1. **Automatic preparation**: Work scripts are prepared by the work-queue-monitor hook
2. **Manual execution**: Use this command to execute prepared work
3. **Continuous flow**: Each completed work item prepares the next

## Related Commands

- `/switch-persona` - Change active persona
- `/show-context` - View current work context
- `/journal-summary` - See overall work status
