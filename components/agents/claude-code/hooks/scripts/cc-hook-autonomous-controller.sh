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

# Look for initial work assignment (from user prompt) - ENHANCED DETECTION
INITIAL_WORK=$(grep -E -i "create.*persona.*project|build.*persona.*application|develop.*persona.*system|make.*persona.*project|create.*hello.*persona|initiate.*architect.*persona" ~/workspace/JOURNAL.md | tail -1)

# Also check for natural language project requests that mention specific languages
if [ -z "$INITIAL_WORK" ]; then
    INITIAL_WORK=$(grep -E -i "create.*project.*python|create.*project.*node|create.*project.*rust|create.*project.*go" ~/workspace/JOURNAL.md | tail -1)
fi

# Check if we already have work assigned
if [ -n "$INITIAL_WORK" ] && ! grep -q "TYPE:WORK_ASSIGNED" ~/workspace/JOURNAL.md; then
    # This is a fresh start - assign work to ARCHITECT
    echo "Found initial request: $INITIAL_WORK" >&2
    
    # Extract project type and language if possible
    PROJECT_DESC="project"
    if echo "$INITIAL_WORK" | grep -qi "hello.*persona"; then
        PROJECT_DESC="hello persona project"
    fi
    
    LANGUAGE=""
    if echo "$INITIAL_WORK" | grep -qi "python"; then
        LANGUAGE=" in Python"
    elif echo "$INITIAL_WORK" | grep -qi "node\|javascript"; then
        LANGUAGE=" in Node.js"
    elif echo "$INITIAL_WORK" | grep -qi "rust"; then
        LANGUAGE=" in Rust"
    elif echo "$INITIAL_WORK" | grep -qi "go\|golang"; then
        LANGUAGE=" in Go"
    fi
    
    # Generate work IDs with timestamp
    TIMESTAMP=$(date +%s)
    
    # Emit proper work assignments
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-init-1|WORK:Create system architecture for ${PROJECT_DESC}${LANGUAGE}"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-init-2|WORK:Design API specification and interfaces"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-init-3|WORK:Define data models and schemas"
    es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-init-4|WORK:Create comprehensive testing strategy"
    
    echo "Assigned initial work to ARCHITECT" >&2
fi

# Check for any pending work that needs processing
PENDING_COUNT=0
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    count=$(es-projection.sh "$persona" "pending_work" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
        echo "Found $count pending items for $persona" >&2
        PENDING_COUNT=$((PENDING_COUNT + count))
    fi
done

if [ "$PENDING_COUNT" -gt 0 ]; then
    echo "Total pending work items: $PENDING_COUNT" >&2
fi

echo "Autonomous system initialized - event monitor running as PID $MONITOR_PID" >&2

# Always exit 0 to allow Claude Code to end gracefully
exit 0
