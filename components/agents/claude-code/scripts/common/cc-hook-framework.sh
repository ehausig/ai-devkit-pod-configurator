#!/bin/bash
# Hook framework for Claude Code
# Provides common functionality for all hooks

# Ensure /usr/local/bin is in PATH
export PATH="/usr/local/bin:$PATH"

# Source common functions
# Try multiple methods to find the script
if [ -f "/usr/local/bin/cc-common.sh" ]; then
    source /usr/local/bin/cc-common.sh
elif [ -f "cc-common.sh" ]; then
    source cc-common.sh
else
    echo "Error: Cannot find cc-common.sh" >&2
    exit 1
fi

# Read JSON input once
JSON_INPUT=$(cat)

# Extract common fields
TOOL_NAME=$(extract_json_field "$JSON_INPUT" '.tool_name')
SESSION_ID=$(extract_json_field "$JSON_INPUT" '.session_id' 'unknown')
HOOK_TYPE="${1:-unknown}"

# Detect hook event type from JSON input
HOOK_EVENT_NAME=$(extract_json_field "$JSON_INPUT" '.hook_event_name')
if [ -n "$HOOK_EVENT_NAME" ]; then
    case "$HOOK_EVENT_NAME" in
        "Stop")
            HOOK_TYPE="journal"
            ;;
        "PreToolUse")
            # Keep existing hook type determination
            ;;
        "PostToolUse")
            # Keep existing hook type determination
            ;;
        "Notification")
            HOOK_TYPE="notification"
            ;;
        "SubagentStop")
            HOOK_TYPE="journal"
            ;;
    esac
fi

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

# Export JSON and core variables for hook scripts
export JSON_INPUT TOOL_NAME SESSION_ID HOOK_TYPE

# Export hook context environment variables so persona scripts can detect hook execution
export HOOK_TYPE
export JSON_INPUT
export TOOL_NAME
export SESSION_ID

# Allow hook scripts to use these functions
export -f is_post_tool_use get_command get_description get_file_path
export -f is_command_successful get_error_details log_hook_event
export -f extract_json_field

# Execute hook-specific logic
# Try to find the logic script in PATH or absolute path
find_and_source_script() {
    local script_name="$1"
    if [ -f "/usr/local/bin/$script_name" ]; then
        source "/usr/local/bin/$script_name"
    elif command -v "$script_name" >/dev/null 2>&1; then
        source "$(command -v "$script_name")"
    else
        echo "Error: Cannot find $script_name" >&2
        exit 1
    fi
}

case "$HOOK_TYPE" in
    "bash-logger")
        find_and_source_script "cc-hook-logic-bash-logger.sh"
        ;;
    "decision-tracker")
        find_and_source_script "cc-hook-logic-decision-tracker.sh"
        ;;
    "error-recovery")
        find_and_source_script "cc-hook-logic-error-recovery.sh"
        ;;
    "file-milestone")
        find_and_source_script "cc-hook-logic-file-milestone.sh"
        ;;
    "format-code")
        find_and_source_script "cc-hook-logic-format-code.sh"
        ;;
    "journal")
        find_and_source_script "cc-hook-logic-journal.sh"
        ;;
    "notification")
        find_and_source_script "cc-hook-logic-notification.sh"
        ;;
    "persona-manager")
        find_and_source_script "cc-hook-logic-persona-manager.sh"
        ;;
    "project-lifecycle")
        find_and_source_script "cc-hook-logic-project-lifecycle.sh"
        ;;
    "session-tracker")
        find_and_source_script "cc-hook-logic-session-tracker.sh"
        ;;
    "test-tracker")
        find_and_source_script "cc-hook-logic-test-tracker.sh"
        ;;
    "work-queue-monitor")
        find_and_source_script "cc-hook-logic-work-queue-monitor.sh"
        ;;
    *)
        echo "Unknown hook type: $HOOK_TYPE" >&2
        exit 1
        ;;
esac

# Always exit successfully unless hook explicitly fails
hook_success_response
