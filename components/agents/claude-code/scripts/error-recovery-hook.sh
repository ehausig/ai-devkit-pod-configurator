#!/bin/bash
# Error and recovery tracking hook logic
# Called by hook-framework.sh

command=$(get_command)
description=$(get_description)

if is_post_tool_use; then
    if is_command_successful; then
        success="true"
    else
        success="false"
    fi
    
    # Log failed commands
    if [ "$success" = "false" ]; then
        log_hook_event "ERROR" "Command failed: $command - $description"
        
        # Log stderr if available
        stderr=$(get_error_details)
        if [ -n "$stderr" ]; then
            log_hook_event "ERROR" "Error output: $stderr"
        fi
        
        # Track specific error types
        case "$command" in
            *"git"*)
                log_hook_event "ERROR" "Git operation failed - may need conflict resolution"
                ;;
            *"npm install"*|*"pip install"*)
                log_hook_event "ERROR" "Dependency installation failed - check requirements"
                ;;
            *"docker"*)
                log_hook_event "ERROR" "Docker operation failed - check Docker daemon"
                ;;
        esac
    fi
    
    # Track recovery actions
    if [ "$success" = "true" ]; then
        # Git conflict resolution
        if [[ "$command" =~ git[[:space:]]checkout[[:space:]]--theirs ]] || [[ "$command" =~ git[[:space:]]checkout[[:space:]]--ours ]]; then
            log_hook_event "RECOVERY" "Resolved git conflict using checkout strategy"
        fi
        
        # Force operations (recovery attempts)
        if [[ "$command" =~ --force ]] || [[ "$command" =~ -f[[:space:]] ]]; then
            log_hook_event "RECOVERY" "Used force flag to overcome issue"
        fi
        
        # Retry patterns
        if [[ "$description" =~ [Rr]etry ]] || [[ "$description" =~ again ]]; then
            log_hook_event "RECOVERY" "Retrying previous operation"
        fi
    fi
fi
