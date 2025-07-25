---
description: Add events to the development journal
---

# Event Emit

Add structured events to the development journal.

## Usage

`/event-emit <type> <persona> <description>`

## Examples

```bash
# Work assignment
/event-emit WORK_ASSIGNED DEVELOPER "Implement user authentication"

# Work completion  
/event-emit WORK_COMPLETE DEVELOPER "Implemented user authentication"

# Decisions
/event-emit DECISION ARCHITECT "Using PostgreSQL for data persistence"

# Handoffs
/event-emit HANDOFF "DEVELOPER->QA" "Implementation complete"

# File creation
/event-emit FILE_CREATED DEVELOPER "src/auth.py"

# Test results
/event-emit TEST_RESULT QA "Unit tests: 45 passed, 0 failed"
```

## Implementation

```bash
# Parse arguments
EVENT_TYPE="$1"
PERSONA="$2"
shift 2
DESCRIPTION="$*"

# Validate arguments
if [ -z "$EVENT_TYPE" ] || [ -z "$PERSONA" ] || [ -z "$DESCRIPTION" ]; then
    echo "Usage: /event-emit <type> <persona> <description>"
    echo ""
    echo "Event types: WORK_ASSIGNED, WORK_STARTED, WORK_COMPLETE, DECISION,"
    echo "            HANDOFF, FILE_CREATED, TEST_RESULT, etc."
    exit 1
fi

# Ensure journal exists
mkdir -p ~/workspace
if [ ! -f ~/workspace/JOURNAL.md ]; then
    echo "# Development Journal" > ~/workspace/JOURNAL.md
    echo "" >> ~/workspace/JOURNAL.md
    echo "## Events" >> ~/workspace/JOURNAL.md
fi

# Add timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Write event to journal
echo "$TIMESTAMP | $EVENT_TYPE | $PERSONA | $DESCRIPTION" >> ~/workspace/JOURNAL.md

echo "✓ Event added to journal"
echo "  Type: $EVENT_TYPE"
echo "  Persona: $PERSONA"
echo "  Description: $DESCRIPTION"
```

## Event Types

Common event types used by the system:

- `WORK_ASSIGNED` - New task assigned to persona
- `WORK_STARTED` - Persona began working on task
- `WORK_COMPLETE` - Task completed successfully
- `DECISION` - Architectural or implementation decision
- `HANDOFF` - Work handed to another persona
- `FILE_CREATED` - New file created
- `FILE_UPDATED` - Existing file modified
- `TEST_RESULT` - Test execution results
- `TEST_COVERAGE` - Code coverage report
- `REVIEW_ISSUE` - Issue found during review
- `QA_ISSUE` - Issue found during testing
- `CYCLE_COMPLETE` - Development cycle finished

## Notes

- Events are the primary communication mechanism between personas
- All events are timestamped in UTC
- The journal serves as the persistent event store
- Events drive the autonomous workflow
