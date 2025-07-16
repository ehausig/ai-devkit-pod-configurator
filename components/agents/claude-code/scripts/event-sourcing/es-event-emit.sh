#!/bin/bash
# Event emission system for structured events in the journal
# Usage: es-event-emit TYPE "KEY:VALUE|KEY:VALUE..."

TYPE="$1"
FIELDS="$2"
JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"

# Ensure journal exists
if [ ! -f "$JOURNAL_FILE" ]; then
    echo "# Development Journal" > "$JOURNAL_FILE"
    echo "" >> "$JOURNAL_FILE"
fi

# Validate event type
if [ -z "$TYPE" ]; then
    echo "Error: Event type required" >&2
    echo "Usage: es-event-emit TYPE \"KEY:VALUE|KEY:VALUE...\"" >&2
    exit 1
fi

# Validate required fields based on event type
case "$TYPE" in
    WORK_ASSIGNED)
        # Required: TO (persona), ID (unique work ID), WORK (description)
        [[ "$FIELDS" =~ TO: ]] || { echo "Missing required field: TO" >&2; exit 1; }
        [[ "$FIELDS" =~ ID: ]] || { echo "Missing required field: ID" >&2; exit 1; }
        [[ "$FIELDS" =~ WORK: ]] || { echo "Missing required field: WORK" >&2; exit 1; }
        ;;
    WORK_STARTED)
        # Required: PERSONA, WORK_ID
        [[ "$FIELDS" =~ PERSONA: ]] || { echo "Missing required field: PERSONA" >&2; exit 1; }
        [[ "$FIELDS" =~ WORK_ID: ]] || { echo "Missing required field: WORK_ID" >&2; exit 1; }
        ;;
    WORK_COMPLETED|WORK_FAILED)
        # Required: PERSONA, WORK_ID
        [[ "$FIELDS" =~ PERSONA: ]] || { echo "Missing required field: PERSONA" >&2; exit 1; }
        [[ "$FIELDS" =~ WORK_ID: ]] || { echo "Missing required field: WORK_ID" >&2; exit 1; }
        ;;
    PERSONA_ACTIVATED|PERSONA_IDLE)
        # Required: PERSONA
        [[ "$FIELDS" =~ PERSONA: ]] || { echo "Missing required field: PERSONA" >&2; exit 1; }
        ;;
    HANDOFF_READY)
        # Required: FROM, TO
        [[ "$FIELDS" =~ FROM: ]] || { echo "Missing required field: FROM" >&2; exit 1; }
        [[ "$FIELDS" =~ TO: ]] || { echo "Missing required field: TO" >&2; exit 1; }
        ;;
    CYCLE_COMPLETE)
        # Required: FINAL_PERSONA
        [[ "$FIELDS" =~ FINAL_PERSONA: ]] || { echo "Missing required field: FINAL_PERSONA" >&2; exit 1; }
        ;;
    MONITOR_STARTED|MONITOR_STOPPED)
        # Required: PID
        [[ "$FIELDS" =~ PID: ]] || { echo "Missing required field: PID" >&2; exit 1; }
        ;;
    HANDOFF_INITIATED)
        # Required: FROM, REASON
        [[ "$FIELDS" =~ FROM: ]] || { echo "Missing required field: FROM" >&2; exit 1; }
        [[ "$FIELDS" =~ REASON: ]] || { echo "Missing required field: REASON" >&2; exit 1; }
        ;;
    # Decision and memory events don't have required fields beyond type
    DECISION|MEMORY|CONTEXT|ISSUE|RESOLVED|INFO|ERROR|WARNING)
        # These are for human-readable logging
        ;;
    *)
        # Unknown event types are allowed for extensibility
        ;;
esac

# Emit event with timestamp
echo "$(date -Iseconds) [EVENT] TYPE:$TYPE|$FIELDS" >> "$JOURNAL_FILE"

# For important events, also log a human-readable version
case "$TYPE" in
    WORK_ASSIGNED)
        if [[ "$FIELDS" =~ TO:([^|]+) ]] && [[ "$FIELDS" =~ WORK:(.+)$ ]]; then
            echo "$(date -Iseconds) [${BASH_REMATCH[1]}:ASSIGNED] ${BASH_REMATCH[2]}" >> "$JOURNAL_FILE"
        fi
        ;;
    WORK_COMPLETED)
        if [[ "$FIELDS" =~ PERSONA:([^|]+) ]] && [[ "$FIELDS" =~ WORK_ID:([^|]+) ]]; then
            echo "$(date -Iseconds) [${BASH_REMATCH[1]}:COMPLETED] Work item ${BASH_REMATCH[2]}" >> "$JOURNAL_FILE"
        fi
        ;;
    HANDOFF_READY)
        if [[ "$FIELDS" =~ FROM:([^|]+) ]] && [[ "$FIELDS" =~ TO:([^|]+) ]]; then
            echo "$(date -Iseconds) [${BASH_REMATCH[1]}:HANDOFF] Ready to hand off to ${BASH_REMATCH[2]}" >> "$JOURNAL_FILE"
        fi
        ;;
esac

# Success - no output unless DEBUG
[ -n "$DEBUG" ] && echo "Event emitted: TYPE:$TYPE|$FIELDS"
