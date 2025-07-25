---
description: Initialize a new project with the autonomous development system
---

# Initialize Autonomous Project

Start a new project using the event-driven autonomous development system.

## Instructions

When the user requests to create a project (e.g., "create a hello persona project in Python"), follow these steps:

```bash
# First, ensure the event monitor is running
if ! pgrep -f "es-event-monitor.sh" > /dev/null 2>&1; then
    echo "Starting event monitor..."
    nohup es-event-monitor.sh > /tmp/event-monitor.log 2>&1 &
    MONITOR_PID=$!
    echo "Event monitor started (PID: $MONITOR_PID)"
    sleep 2  # Give it time to start
fi

# Extract project details from the request
PROJECT_NAME="[extracted project name]"
LANGUAGE="[extracted language or empty]"
TIMESTAMP=$(date +%s)

# Create initial work assignments for ARCHITECT
echo "Emitting work assignments to ARCHITECT..."
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-1|WORK:Create system architecture for ${PROJECT_NAME}${LANGUAGE}"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-2|WORK:Design API specification and interfaces"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-3|WORK:Define data models and schemas"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-4|WORK:Create comprehensive testing strategy"

# Verify events were emitted
echo "Checking journal for events..."
tail -5 ~/workspace/JOURNAL.md

# Show monitoring instructions
echo ""
echo "Project initialization complete!"
echo ""
echo "Monitor progress with:"
echo "  tail -f ~/workspace/JOURNAL.md | grep EVENT"
echo ""
echo "Check system status with:"
echo "  es-projection.sh \"\" system_state"
echo ""
echo "The ARCHITECT persona will activate automatically and begin work."
```

## Examples

For "create a hello persona project in Python":
```bash
PROJECT_NAME="hello persona project"
LANGUAGE=" in Python"
```

For "build a REST API":
```bash
PROJECT_NAME="REST API"
LANGUAGE=""
```

## Troubleshooting

If the system doesn't start:

1. Check if events are in the journal:
   ```bash
   grep "TYPE:WORK_ASSIGNED" ~/workspace/JOURNAL.md
   ```

2. Check if event monitor is running:
   ```bash
   ps aux | grep es-event-monitor.sh
   ```

3. Check ARCHITECT status:
   ```bash
   es-projection.sh ARCHITECT current_state
   es-projection.sh ARCHITECT pending_work
   ```

4. Check monitor log for errors:
   ```bash
   tail -20 /tmp/event-monitor.log
   ```

## Notes

- The event monitor MUST be running for personas to activate
- Each persona will hand off work to the next when complete
- The system runs autonomously without further intervention
- Events must NOT contain shell redirections like "< /dev/null"
