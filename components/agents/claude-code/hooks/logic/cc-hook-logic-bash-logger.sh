#!/bin/bash
# Bash command logging hook logic
# Called by hook-framework.sh

# Ensure functions are available
if ! type -t get_command >/dev/null 2>&1; then
    # Try to source the wrapper
    if [ -f "/usr/local/bin/cc-hook-logic-wrapper.sh" ]; then
        source /usr/local/bin/cc-hook-logic-wrapper.sh
    fi
fi

# Get command details
command=$(get_command)
description=$(get_description)

if is_post_tool_use; then
    # PostToolUse - command was executed
    if is_command_successful; then
        success="true"
    else
        success="false"
    fi
    
    # Intelligent categorization based on command
    type="INFO"
    
    # File operations
    [[ "$command" =~ ^(touch|mkdir|cp|mv|rm) ]] && type="STRUCTURE"
    
    # Git operations
    [[ "$command" =~ ^git[[:space:]] ]] && type="GIT"
    [[ "$command" =~ ^gh[[:space:]] ]] && type="GITHUB"
    
    # Package management
    [[ "$command" =~ ^(npm|yarn|pnpm)[[:space:]] ]] && type="NPM"
    [[ "$command" =~ ^(pip|pipenv|poetry)[[:space:]] ]] && type="PIP"
    [[ "$command" =~ ^cargo[[:space:]] ]] && type="CARGO"
    [[ "$command" =~ ^go[[:space:]] ]] && type="GO"
    [[ "$command" =~ ^(bundle|gem)[[:space:]] ]] && type="RUBY"
    [[ "$command" =~ ^(mvn|gradle)[[:space:]] ]] && type="JAVA"
    
    # Testing
    [[ "$command" =~ test ]] && type="TEST"
    [[ "$command" =~ coverage ]] && type="COVERAGE"
    
    # Docker
    [[ "$command" =~ ^docker[[:space:]] ]] && type="DOCKER"
    [[ "$command" =~ ^docker-compose[[:space:]] ]] && type="COMPOSE"
    
    # Environment
    [[ "$command" =~ ^(export|source|eval) ]] && type="ENV"
    
    # Build tools
    [[ "$command" =~ ^make[[:space:]] ]] && type="BUILD"
    
    if [ "$success" = "true" ]; then
        log_hook_event "$type" "$command"
    else
        log_hook_event "ERROR" "Failed: $command - $description"
        # Log stderr if present
        stderr=$(get_error_details)
        if [ -n "$stderr" ]; then
            log_hook_event "ERROR" "stderr: $stderr"
        fi
    fi
else
    # PreToolUse - only log significant operations we want to track before execution
    case "$command" in
        "rm -rf"*|"sudo"*)
            log_hook_event "WARNING" "Preparing dangerous command: $command"
            ;;
        *"production"*|*"deploy"*)
            log_hook_event "WARNING" "Production operation pending: $command"
            ;;
    esac
fi
