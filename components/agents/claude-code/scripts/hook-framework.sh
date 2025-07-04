#!/bin/bash
# Hook framework for Claude Code
# Provides common functionality for all hooks

# Source common functions
source /usr/local/bin/claude-code-common.sh

# Read JSON input once
JSON_INPUT=$(cat)

# Extract common fields
TOOL_NAME=$(extract_json_field "$JSON_INPUT" '.tool_name')
SESSION_ID=$(extract_json_field "$JSON_INPUT" '.session_id' 'unknown')
HOOK_TYPE="${1:-unknown}"

# Check if this is pre or post execution
is_post_tool_use() {
    echo "$JSON_INPUT" | jq -e '.tool_response' > /dev/null 2>&1
}

# Extract command details
get_command() {
    extract_json_field "$JSON_INPUT" '.tool_input.command'
}

get_description() {
    extract_json_field "$JSON_INPUT" '.tool_input.description' 'No description'
}

get_file_path() {
    local path=$(extract_json_field "$JSON_INPUT" '.tool_input.file_path')
    if [ -z "$path" ] || [ "$path" = "null" ]; then
        path=$(extract_json_field "$JSON_INPUT" '.tool_input.path')
    fi
    echo "$path"
}

# Check command success (for PostToolUse)
is_command_successful() {
    if ! is_post_tool_use; then
        return 1
    fi
    
    local interrupted=$(extract_json_field "$JSON_INPUT" '.tool_response.interrupted' 'false')
    local stderr=$(extract_json_field "$JSON_INPUT" '.tool_response.stderr')
    
    if [ "$interrupted" = "false" ] && [ -z "$stderr" ]; then
        return 0
    else
        return 1
    fi
}

# Get error details
get_error_details() {
    local stderr=$(extract_json_field "$JSON_INPUT" '.tool_response.stderr')
    echo "$stderr"
}

# Common logging functions
log_hook_event() {
    local tag="$1"
    local message="$2"
    log_event "$tag" "$message"
}

# Export JSON for hook scripts
export JSON_INPUT TOOL_NAME SESSION_ID HOOK_TYPE

# Allow hook scripts to use these functions
export -f is_post_tool_use get_command get_description get_file_path
export -f is_command_successful get_error_details log_hook_event
export -f extract_json_field

# Execute hook-specific logic
case "$HOOK_TYPE" in
    "bash-logger")
        source /usr/local/bin/bash-logger-hook.sh
        ;;
    "decision-tracker")
        source /usr/local/bin/decision-tracker-hook.sh
        ;;
    "error-recovery")
        source /usr/local/bin/error-recovery-hook.sh
        ;;
    "file-milestone")
        source /usr/local/bin/file-milestone-hook.sh
        ;;
    "format-code")
        source /usr/local/bin/format-code-hook.sh
        ;;
    "journal")
        source /usr/local/bin/journal-hook.sh
        ;;
    "notification")
        source /usr/local/bin/notification-hook.sh
        ;;
    "persona-manager")
        source /usr/local/bin/persona-manager-hook.sh
        ;;
    "project-lifecycle")
        source /usr/local/bin/project-lifecycle-hook.sh
        ;;
    "session-tracker")
        source /usr/local/bin/session-tracker-hook.sh
        ;;
    "test-tracker")
        source /usr/local/bin/test-tracker-hook.sh
        ;;
    "work-queue-monitor")
        source /usr/local/bin/work-queue-monitor-hook.sh
        ;;
    *)
        echo "Unknown hook type: $HOOK_TYPE" >&2
        exit 1
        ;;
esac

# Always exit successfully unless hook explicitly fails
hook_success_response
