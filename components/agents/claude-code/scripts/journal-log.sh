#!/bin/bash
# Journal logging utility for consistent event formatting
# Usage: journal-log.sh <EVENT_TYPE> <ACTOR> <DESCRIPTION>

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: journal-log.sh <EVENT_TYPE> <ACTOR> <DESCRIPTION>"
    echo "Example: journal-log.sh AGENT_START architect 'Beginning system design'"
    exit 1
fi

EVENT_TYPE="$1"
ACTOR="$2"
shift 2
DESCRIPTION="$*"

# Generate timestamp
TIMESTAMP=$(date -Iseconds)

# Append to journal
echo "${TIMESTAMP} | ${EVENT_TYPE} | ${ACTOR} | ${DESCRIPTION}" >> "$JOURNAL_PATH"

# Return success
exit 0
