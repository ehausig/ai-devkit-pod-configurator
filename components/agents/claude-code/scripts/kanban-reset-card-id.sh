#!/bin/bash
# Reset the Kanban card ID counter to zero
# Used when initializing a new project

COUNTER_FILE="/home/devuser/.claude/data/kanban-last-card-id"

# Ensure data directory exists with proper permissions
mkdir -p "$(dirname "$COUNTER_FILE")"
chmod 755 "$(dirname "$COUNTER_FILE")"

# Reset counter to 0
echo "0" > "$COUNTER_FILE"
chmod 644 "$COUNTER_FILE"

# Confirm reset
echo "Kanban card counter reset to 0"
