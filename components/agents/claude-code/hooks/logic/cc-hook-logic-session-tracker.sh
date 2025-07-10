#!/bin/bash
# Session tracking hook logic
# Called by hook-framework.sh

# Extract command and description
command=$(get_command)
description=$(get_description)

# Check if this is a cd command to track working directory
if [[ "$command" =~ ^cd[[:space:]] ]]; then
    target_dir=$(echo "$command" | sed 's/^cd[[:space:]]*//')
    # Handle complex cd commands (like cd ~/workspace && pwd)
    if echo "$target_dir" | grep -q '[[:space:]]&&'; then
        target_dir=$(echo "$target_dir" | sed 's/[[:space:]]&&.*//')
    fi
    # Resolve the full path
    if [[ "$target_dir" =~ ^~ ]]; then
        # Replace ~ with $HOME, not concatenate
        target_dir="${target_dir/#\~/$HOME}"
    fi
    log_hook_event "INFO" "Working directory: $target_dir"
fi

# Track workspace initialization
if [[ "$command" =~ mkdir.*workspace ]]; then
    log_hook_event "INFO" "Initializing workspace structure"
fi
