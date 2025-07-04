#!/bin/bash
# Journal hook logic for Stop events
# Called by hook-framework.sh

# For Stop event, we'll log that the session completed
type="INFO"
message="Claude Code session completed"

# Check if this is a stop hook that's already active to prevent loops
stop_hook_active=$(extract_json_field "$JSON_INPUT" '.stop_hook_active' 'false')

if [ "$stop_hook_active" = "true" ]; then
    # Don't create recursive journal entries
    exit 0
fi

# Create the journal entry
log_hook_event "$type" "Session $SESSION_ID completed - $message"
