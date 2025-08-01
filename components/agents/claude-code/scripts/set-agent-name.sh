#!/bin/bash
# Set the current agent name for journal logging
# Usage: set-agent-name.sh <agent-name>
# This avoids using export which can trigger permission prompts

DATA_DIR="/home/devuser/.claude/data"
AGENT_FILE="$DATA_DIR/current-agent-name"

if [ $# -lt 1 ]; then
    echo "Usage: set-agent-name.sh <agent-name>"
    exit 1
fi

AGENT_NAME="$1"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Write the agent name to the data file
echo "$AGENT_NAME" > "$AGENT_FILE"

# Set restrictive permissions
chmod 600 "$AGENT_FILE"

# Confirm it was set
echo "Agent name set to: $AGENT_NAME"
