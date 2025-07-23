#!/bin/bash
# Custom notification hook logic
# Called by hook-framework.sh

# Ensure functions are available
if ! type -t extract_json_field >/dev/null 2>&1; then
    # Try to source the wrapper
    if [ -f "/usr/local/bin/cc-hook-logic-wrapper.sh" ]; then
        source /usr/local/bin/cc-hook-logic-wrapper.sh
    fi
fi

# Extract notification details
message=$(extract_json_field "$JSON_INPUT" '.message' 'Claude Code notification')
title=$(extract_json_field "$JSON_INPUT" '.title' 'Claude Code')

# Log to journal
log_hook_event "NOTIFICATION" "$title: $message"

# Try different notification methods
# 1. Try notify-send (if available in container)
if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message" 2>/dev/null || true
fi

# 2. Write to a notification file that could be monitored
echo "$(date -Iseconds) | $title | $message" >> ~/workspace/.notifications.log

# 3. If running in a terminal, use terminal bell
if [ -t 1 ]; then
    echo -e "\a"  # Terminal bell
    echo "🔔 $title: $message"
fi
