#!/bin/bash
# Project lifecycle tracking hook logic
# Called by hook-framework.sh

# Extract command details
command=$(get_command)
description=$(get_description)

# Only log successful commands
if is_post_tool_use && is_command_successful; then
    # Git repository initialization
    if [[ "$command" == "git init" ]]; then
        working_dir=$(pwd)
        log_hook_event "INFO" "Git repository initialized in $working_dir"
    fi
    
    # GitHub repo creation
    if [[ "$command" =~ ^gh[[:space:]]repo[[:space:]]create ]]; then
        repo_name=$(echo "$command" | grep -oE 'create[[:space:]]+[^ ]+' | awk '{print $2}')
        if [[ -n "$repo_name" ]]; then
            log_hook_event "MILESTONE" "GitHub repo created: $repo_name"
        fi
    fi
    
    # Branch creation/checkout
    if [[ "$command" =~ git[[:space:]]checkout[[:space:]]-b ]]; then
        branch_name=$(echo "$command" | grep -oE '\-b[[:space:]]+[^ ]+' | awk '{print $2}')
        log_hook_event "INFO" "Created feature branch: $branch_name"
    fi
    
    # Git commits
    if [[ "$command" =~ ^git[[:space:]]commit ]]; then
        commit_msg=$(echo "$command" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
        if [[ -n "$commit_msg" ]]; then
            log_hook_event "MILESTONE" "Committed: $commit_msg"
        fi
    fi
    
    # PR creation
    if [[ "$command" =~ ^gh[[:space:]]pr[[:space:]]create ]]; then
        log_hook_event "MILESTONE" "Pull request created"
    fi
    
    # Project structure creation
    if [[ "$command" =~ mkdir.*-p.*(src|tests|docs) ]]; then
        log_hook_event "INFO" "Project structure created"
    fi
    
    # Environment setup
    if [[ "$command" =~ (python|node|cargo|go)[[:space:]]init ]] || [[ "$command" =~ npm[[:space:]]init ]]; then
        log_hook_event "INFO" "Development environment initialized"
    fi
    
    # Dependency installation
    if [[ "$command" =~ ^(npm|pip|cargo|go|bundle)[[:space:]]install ]]; then
        log_hook_event "INFO" "Dependencies installed"
    fi
fi
