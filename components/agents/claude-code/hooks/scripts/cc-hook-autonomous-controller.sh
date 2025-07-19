#!/bin/bash
# Simplified autonomous controller hook - ensures event monitor is running
# This is triggered by the Stop hook when Claude Code session ends

# Get JSON input from Claude Code hook system
JSON_INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$JSON_INPUT" | jq -r '.session_id // "unknown"')

# Check if autonomous mode is enabled
AUTONOMOUS_MODE="${CLAUDE_AUTONOMOUS_MODE:-false}"
if [ "$AUTONOMOUS_MODE" != "true" ]; then
    echo "Autonomous mode disabled - session ending normally" >&2
    exit 0
fi

# Check if event monitor is already running
if pgrep -f "es-event-monitor.sh" > /dev/null 2>&1; then
    echo "Event monitor already running" >&2
    exit 0
fi

# Start the event monitor in background
echo "Starting event monitor for autonomous operation" >&2
nohup es-event-monitor.sh > /tmp/event-monitor.log 2>&1 &
MONITOR_PID=$!

# Emit event about monitor starting
es-event-emit.sh "MONITOR_STARTED" "PID:$MONITOR_PID|SESSION:$SESSION_ID|TRIGGER:STOP_HOOK"

# Check if there's work to be done
echo "Checking for pending work or handoffs..." >&2

# Look for initial work assignment (from user prompt)
INITIAL_WORK=$(grep -E "Create.*app|Build.*application|Develop.*system|Make.*project" ~/workspace/JOURNAL.md | tail -1)

if [ -n "$INITIAL_WORK" ] && ! grep -q "TYPE:WORK_ASSIGNED" ~/workspace/JOURNAL.md; then
    # This is a fresh start - assign work to ARCHITECT
    echo "Found initial request: $INITIAL_WORK" >&2
    WORK_ID="$(date +%s)-init-1"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$WORK_ID|WORK:Create system architecture based on requirements"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-init-2|WORK:Design API specification"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-init-3|WORK:Define data models and schemas"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-init-4|WORK:Create testing strategy"
fi

echo "Autonomous system initialized - event monitor running as PID $MONITOR_PID" >&2

# Always exit 0 to allow Claude Code to end gracefully
exit 0
