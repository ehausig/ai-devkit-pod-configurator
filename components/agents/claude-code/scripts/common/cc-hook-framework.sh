#!/bin/bash
# Hook framework for Claude Code
# Provides common functionality for all hooks

# Ensure /usr/local/bin is in PATH
export PATH="/usr/local/bin:$PATH"

# CRITICAL: Store JOURNAL_FILE in a unique variable that won't be overwritten
if [ -n "$JOURNAL_FILE" ]; then
    export _HOOK_FRAMEWORK_JOURNAL_FILE="$JOURNAL_FILE"
fi

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

# CRITICAL: Restore JOURNAL_FILE after sourcing common
if [ -n "$_HOOK_FRAMEWORK_JOURNAL_FILE" ]; then
    export JOURNAL_FILE="$_HOOK_FRAMEWORK_JOURNAL_FILE"
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

# Define all hook helper functions before exporting
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

# CRITICAL: Export JOURNAL_FILE to ensure it's available to sourced scripts
export JOURNAL_FILE
export _HOOK_FRAMEWORK_JOURNAL_FILE

# Allow hook scripts to use these functions - CRITICAL: export all functions
export -f is_post_tool_use get_command get_description get_file_path
export -f is_command_successful get_error_details log_hook_event
export -f extract_json_field log_event ensure_journal

# Source the wrapper to ensure all functions are available
if [ -f "/usr/local/bin/cc-hook-logic-wrapper.sh" ]; then
    source /usr/local/bin/cc-hook-logic-wrapper.sh
elif [ -f "$(dirname "$0")/cc-hook-logic-wrapper.sh" ]; then
    source "$(dirname "$0")/cc-hook-logic-wrapper.sh"
fi

# Restore JOURNAL_FILE again after sourcing wrapper
if [ -n "$_HOOK_FRAMEWORK_JOURNAL_FILE" ]; then
    export JOURNAL_FILE="$_HOOK_FRAMEWORK_JOURNAL_FILE"
fi

# Execute hook-specific logic
# Try to find the logic script in PATH or absolute path
find_and_source_script() {
    local script_name="$1"
    
    if [ -f "/usr/local/bin/$script_name" ]; then
        # Source in current shell to preserve function exports
        source "/usr/local/bin/$script_name"
    elif command -v "$script_name" >/dev/null 2>&1; then
        source "$(command -v "$script_name")"
    else
        echo "Error: Cannot find $script_name" >&2
        exit 1
    fi
    
    # Always restore JOURNAL_FILE after sourcing
    if [ -n "$_HOOK_FRAMEWORK_JOURNAL_FILE" ]; then
        export JOURNAL_FILE="$_HOOK_FRAMEWORK_JOURNAL_FILE"
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
    "project-init")
        find_and_source_script "cc-hook-logic-project-init.sh"
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
