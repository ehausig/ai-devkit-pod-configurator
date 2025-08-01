#!/bin/bash
# Set the current agent name for journal logging
# Usage: set-agent-name.sh <agent-name>
# This avoids using export which can trigger permission prompts
# Also logs agent activation events for activity tracking

DATA_DIR="/home/devuser/.claude/data"
AGENT_FILE="$DATA_DIR/current-agent-name"

if [ $# -lt 1 ]; then
    echo "Usage: set-agent-name.sh <agent-name>"
    exit 1
fi

AGENT_NAME="$1"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Get the previous agent name if any
PREVIOUS_AGENT=""
if [ -f "$AGENT_FILE" ]; then
    PREVIOUS_AGENT=$(cat "$AGENT_FILE" 2>/dev/null || echo "")
fi

# Write the agent name to the data file
echo "$AGENT_NAME" > "$AGENT_FILE"

# Set restrictive permissions
chmod 600 "$AGENT_FILE"

# Log agent activation event (but only if we're not setting product-manager during init)
# This helps track agent activity in the Kanban dashboard
if [ -n "$PREVIOUS_AGENT" ] && [ "$PREVIOUS_AGENT" != "$AGENT_NAME" ]; then
    # Only log if we're switching agents, not on initial setup
    # The journal-log-json.sh script will handle the activation event
    true  # Placeholder - activation is now handled in journal-log-json.sh
fi

# Confirm it was set
echo "Agent name set to: $AGENT_NAME"
