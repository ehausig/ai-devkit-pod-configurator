#!/bin/bash
# Journal logging utility to avoid echo command approval issues

# Usage: journal-log TAG MESSAGE
# Example: journal-log "ARCHITECT:DECISION" "Chose Python with FastAPI"

if [ $# -lt 2 ]; then
    echo "Usage: journal-log TAG MESSAGE"
    echo "Example: journal-log 'ARCHITECT:DECISION' 'Chose Python with FastAPI'"
    exit 1
fi

TAG="$1"
shift
MESSAGE="$*"

# Create journal file if it doesn't exist
JOURNAL_FILE="$HOME/workspace/JOURNAL.md"
if [ ! -f "$JOURNAL_FILE" ]; then
    echo "# Development Journal" > "$JOURNAL_FILE"
    echo "" >> "$JOURNAL_FILE"
fi

# Append the log entry
echo "$(date -Iseconds) [$TAG] $MESSAGE" >> "$JOURNAL_FILE"

# Show confirmation
echo "✓ Logged to journal: [$TAG] $MESSAGE"
