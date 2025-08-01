#!/bin/bash
# Get the current agent name for journal logging
# Usage: get-agent-name.sh
# Returns the current agent name or "PM" if not set

DATA_DIR="/home/devuser/.claude/data"
AGENT_FILE="$DATA_DIR/current-agent-name"

# If the file exists and is readable, return its contents
if [ -f "$AGENT_FILE" ] && [ -r "$AGENT_FILE" ]; then
    cat "$AGENT_FILE"
else
    # Default to product-manager if no agent is set
    echo "product-manager"
fi
