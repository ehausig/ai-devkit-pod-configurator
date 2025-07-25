#!/bin/bash
# Event emission system for structured events in the journal
# Usage: es-event-emit TYPE "KEY:VALUE|KEY:VALUE..."

TYPE="$1"
FIELDS="$2"
JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"

# Clean up any shell artifacts from the input
# Remove any "< /dev/null" or similar redirections that might have been injected
TYPE=$(echo "$TYPE" | sed 's/< \/dev\/null//g' | sed 's/[[:space:]]*$//')
FIELDS=$(echo "$FIELDS" | sed 's/< \/dev\/null//g')

# Validation helper function
validate_and_exit() {
  echo "$1" >&2
  exit 1
}

# Ensure journal exists
if [ ! -f "$JOURNAL_FILE" ]; then
  echo "# Development Journal" >"$JOURNAL_FILE"
  echo "" >>"$JOURNAL_FILE"
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
  [[ "$FIELDS" =~ TO: ]] || validate_and_exit "Missing required field: TO"
  [[ "$FIELDS" =~ ID: ]] || validate_and_exit "Missing required field: ID"
  [[ "$FIELDS" =~ WORK: ]] || validate_and_exit "Missing required field: WORK"
  ;;
WORK_STARTED)
  # Required: PERSONA, WORK_ID
  [[ "$FIELDS" =~ PERSONA: ]] || validate_and_exit "Missing required field: PERSONA"
  [[ "$FIELDS" =~ WORK_ID: ]] || validate_and_exit "Missing required field: WORK_ID"
  ;;
WORK_COMPLETED | WORK_FAILED)
  # Required: PERSONA, WORK_ID
  [[ "$FIELDS" =~ PERSONA: ]] || validate_and_exit "Missing required field: PERSONA"
  [[ "$FIELDS" =~ WORK_ID: ]] || validate_and_exit "Missing required field: WORK_ID"
  ;;
PERSONA_ACTIVATED | PERSONA_IDLE)
  # Required: PERSONA
  [[ "$FIELDS" =~ PERSONA: ]] || validate_and_exit "Missing required field: PERSONA"
  ;;
HANDOFF_READY)
  # Required: FROM, TO
  [[ "$FIELDS" =~ FROM: ]] || validate_and_exit "Missing required field: FROM"
  [[ "$FIELDS" =~ TO: ]] || validate_and_exit "Missing required field: TO"
  ;;
CYCLE_COMPLETE)
  # Required: FINAL_PERSONA
  [[ "$FIELDS" =~ FINAL_PERSONA: ]] || validate_and_exit "Missing required field: FINAL_PERSONA"
  ;;
MONITOR_STARTED | MONITOR_STOPPED)
  # Required: PID
  [[ "$FIELDS" =~ PID: ]] || validate_and_exit "Missing required field: PID"
  ;;
HANDOFF_INITIATED)
  # Required: FROM, REASON
  [[ "$FIELDS" =~ FROM: ]] || validate_and_exit "Missing required field: FROM"
  [[ "$FIELDS" =~ REASON: ]] || validate_and_exit "Missing required field: REASON"
  ;;
# Decision and memory events don't have required fields beyond type
DECISION | MEMORY | CONTEXT | ISSUE | RESOLVED | INFO | ERROR | WARNING)
  # These are for human-readable logging
  ;;
*)
  # Unknown event types are allowed for extensibility
  ;;
esac

# Use file locking to ensure atomic writes
{
  # Try to acquire exclusive lock (will wait if another process has it)
  flock -x 200
  
  # Emit event with timestamp
  echo "$(date -Iseconds) [EVENT] TYPE:$TYPE|$FIELDS" >>"$JOURNAL_FILE"

  # For important events, also log a human-readable version
  case "$TYPE" in
  WORK_ASSIGNED)
    # Extract TO persona - handle potential shell artifacts
    if [[ "$FIELDS" =~ TO:([^|]+) ]]; then
      TO_PERSONA="${BASH_REMATCH[1]}"
      # Clean up any remaining shell artifacts
      TO_PERSONA=$(echo "$TO_PERSONA" | sed 's/< \/dev\/null//g' | sed 's/[[:space:]]*$//')
    fi
    # Extract work description (everything after WORK:)
    if [[ "$FIELDS" =~ WORK:(.+) ]]; then
      WORK_DESC="${BASH_REMATCH[1]}"
      echo "$(date -Iseconds) [${TO_PERSONA}:ASSIGNED] ${WORK_DESC}" >>"$JOURNAL_FILE"
    fi
    ;;
  WORK_COMPLETED)
    if [[ "$FIELDS" =~ PERSONA:([^|]+) ]]; then
      PERSONA="${BASH_REMATCH[1]}"
      PERSONA=$(echo "$PERSONA" | sed 's/< \/dev\/null//g' | sed 's/[[:space:]]*$//')
    fi
    if [[ "$FIELDS" =~ WORK_ID:([^|]+) ]]; then
      WORK_ID="${BASH_REMATCH[1]}"
      echo "$(date -Iseconds) [${PERSONA}:COMPLETED] Work item ${WORK_ID}" >>"$JOURNAL_FILE"
    fi
    ;;
  HANDOFF_READY)
    if [[ "$FIELDS" =~ FROM:([^|]+) ]]; then
      FROM_PERSONA="${BASH_REMATCH[1]}"
      FROM_PERSONA=$(echo "$FROM_PERSONA" | sed 's/< \/dev\/null//g' | sed 's/[[:space:]]*$//')
    fi
    if [[ "$FIELDS" =~ TO:([^|]+) ]]; then
      TO_PERSONA="${BASH_REMATCH[1]}"
      TO_PERSONA=$(echo "$TO_PERSONA" | sed 's/< \/dev\/null//g' | sed 's/[[:space:]]*$//')
      echo "$(date -Iseconds) [${FROM_PERSONA}:HANDOFF] Ready to hand off to ${TO_PERSONA}" >>"$JOURNAL_FILE"
    fi
    ;;
  esac
  
} 200>>"${JOURNAL_FILE}.lock"

# Clean up lock file if it's empty
[ -s "${JOURNAL_FILE}.lock" ] || rm -f "${JOURNAL_FILE}.lock"

# Success - no output unless DEBUG
[ -n "$DEBUG" ] && echo "Event emitted: TYPE:$TYPE|$FIELDS"

# Always exit with success
exit 0
