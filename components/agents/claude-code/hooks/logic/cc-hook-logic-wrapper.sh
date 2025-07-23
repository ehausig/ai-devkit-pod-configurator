#!/bin/bash
# Hook logic wrapper - ensures environment is set up for hook logic scripts

# This wrapper is sourced by cc-hook-framework.sh to ensure all functions are available

# Check if JOURNAL_FILE was preserved by framework
if [ -n "$_HOOK_FRAMEWORK_JOURNAL_FILE" ]; then
    export JOURNAL_FILE="$_HOOK_FRAMEWORK_JOURNAL_FILE"
fi

# Ensure common functions are available
if ! type -t extract_json_field >/dev/null 2>&1; then
    # Source cc-common.sh if functions are missing
    if [ -f "/usr/local/bin/cc-common.sh" ]; then
        # Preserve journal before sourcing
        local _wrapper_journal="$JOURNAL_FILE"
        source /usr/local/bin/cc-common.sh
        # Restore journal after sourcing
        if [ -n "$_wrapper_journal" ]; then
            export JOURNAL_FILE="$_wrapper_journal"
        fi
    fi
fi

# Helper functions that hook logic scripts need
if ! type -t get_command >/dev/null 2>&1; then
    get_command() {
        extract_json_field "$JSON_INPUT" '.tool_input.command'
    }
fi

if ! type -t get_description >/dev/null 2>&1; then
    get_description() {
        extract_json_field "$JSON_INPUT" '.tool_input.description' 'No description'
    }
fi

if ! type -t is_post_tool_use >/dev/null 2>&1; then
    is_post_tool_use() {
        echo "$JSON_INPUT" | jq -e '.tool_response' > /dev/null 2>&1
    }
fi

if ! type -t get_file_path >/dev/null 2>&1; then
    get_file_path() {
        local path=$(extract_json_field "$JSON_INPUT" '.tool_input.file_path')
        if [ -z "$path" ] || [ "$path" = "null" ]; then
            path=$(extract_json_field "$JSON_INPUT" '.tool_input.path')
        fi
        echo "$path"
    }
fi

if ! type -t is_command_successful >/dev/null 2>&1; then
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
fi

if ! type -t get_error_details >/dev/null 2>&1; then
    get_error_details() {
        local stderr=$(extract_json_field "$JSON_INPUT" '.tool_response.stderr')
        echo "$stderr"
    }
fi

# Fixed log_hook_event to ensure it writes to journal
if ! type -t log_hook_event >/dev/null 2>&1; then
    log_hook_event() {
        local tag="$1"
        local message="$2"
        # Ensure journal file exists
        ensure_journal
        # Write directly to journal file
        echo "$(date -Iseconds) [$tag] $message" >> "$JOURNAL_FILE"
    }
fi

# Fixed log_event function
if ! type -t log_event >/dev/null 2>&1; then
    log_event() {
        local tag="$1"
        local message="$2"
        ensure_journal
        echo "$(date -Iseconds) [$tag] $message" >> "$JOURNAL_FILE"
    }
fi

# Ensure ensure_journal is available
if ! type -t ensure_journal >/dev/null 2>&1; then
    ensure_journal() {
        if [ ! -f "$JOURNAL_FILE" ]; then
            echo "# Development Journal" > "$JOURNAL_FILE"
            echo "" >> "$JOURNAL_FILE"
        fi
    }
fi

# Export all functions for the logic script
export -f get_command get_description is_post_tool_use get_file_path
export -f is_command_successful get_error_details log_hook_event
export -f log_event ensure_journal extract_json_field

# Debug output
if [ -n "$DEBUG" ]; then
    echo "Hook wrapper: JOURNAL_FILE is $JOURNAL_FILE" >&2
fi
