#!/bin/bash
# Reconstruct agent context for resuming work
# Usage: agent-context.sh <agent_id> <card_id>

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

if [ $# -lt 2 ]; then
    echo "Usage: agent-context.sh <agent_id> <card_id>"
    exit 1
fi

AGENT_ID="$1"
CARD_ID="$2"

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "{\"decisions\": [], \"files_created\": [], \"files_modified\": [], \"work_performed\": [], \"last_state\": null}"
    exit 0
fi

# Build comprehensive context from agent events
cat "$JOURNAL_PATH" | jq -s "
map(select(.agent == \"$AGENT_ID\" and .data.card_id == \"$CARD_ID\")) |
{
    decisions: map(select(.event_type == \"agent.decision_made\") | {
        timestamp: .timestamp,
        decision: .data.decision,
        rationale: .data.rationale
    }),
    files_created: map(select(.data.files_created) | .data.files_created) | flatten | unique,
    files_modified: map(select(.data.files_modified) | .data.files_modified) | flatten | unique,
    work_performed: map(select(.event_type == \"agent.work_performed\") | {
        timestamp: .timestamp,
        description: .data.work_description,
        tools_used: .data.tools_used
    }),
    errors: map(select(.event_type == \"agent.error_encountered\") | {
        timestamp: .timestamp,
        error: .data.error
    }),
    last_activity: map(.timestamp) | last,
    context_summary: map(select(.data.context_summary)) | last | .data.context_summary
}
"
