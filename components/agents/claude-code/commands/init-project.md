---
description: Initialize a new project with the autonomous development system
---

# Initialize Autonomous Project

Start a new project using the event-driven autonomous development system.

## Instructions

When the user requests to create a project (e.g., "create a hello persona project in Python"), emit the proper work assignments:

```bash
# Extract project details from the request
PROJECT_NAME="[extracted project name]"
LANGUAGE="[extracted language or empty]"
TIMESTAMP=$(date +%s)

# Create initial work assignments for ARCHITECT
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-1|WORK:Create system architecture for ${PROJECT_NAME}${LANGUAGE}"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-2|WORK:Design API specification and interfaces"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-3|WORK:Define data models and schemas"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-4|WORK:Create comprehensive testing strategy"

# Ensure event monitor is running
if ! pgrep -f "es-event-monitor.sh" > /dev/null 2>&1; then
    nohup es-event-monitor.sh > /tmp/event-monitor.log 2>&1 &
    echo "Started event monitor (PID: $!)"
fi

# Show status
echo "Project initialization complete. Monitor progress with:"
echo "tail -f ~/workspace/JOURNAL.md | grep EVENT"
```

## Examples

For "create a hello persona project in Python":
- PROJECT_NAME="hello persona project"
- LANGUAGE=" in Python"

For "build a REST API":
- PROJECT_NAME="REST API"
- LANGUAGE=""

## Notes

- The ARCHITECT persona will be activated automatically
- Each persona will hand off work to the next when complete
- The system runs autonomously without further intervention
