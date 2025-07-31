#!/bin/bash
# Card ID generator for Kanban system
# Generates sequential three-digit IDs for tracking work items

COUNTER_FILE="/home/devuser/.claude/data/kanban-last-card-id"

# Ensure data directory exists
mkdir -p "$(dirname "$COUNTER_FILE")"

# Initialize counter file if it doesn't exist
if [ ! -f "$COUNTER_FILE" ]; then
    echo "0" > "$COUNTER_FILE"
fi

# Read current counter value
CURRENT=$(cat "$COUNTER_FILE")

# Increment counter
NEXT=$((CURRENT + 1))

# Save new counter value
echo "$NEXT" > "$COUNTER_FILE"

# Output formatted ID (three digits with leading zeros)
printf "CARD-%03d\n" "$NEXT"
