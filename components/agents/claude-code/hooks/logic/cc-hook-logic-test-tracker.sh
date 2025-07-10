#!/bin/bash
# Test execution tracking hook logic
# Called by hook-framework.sh

# Extract command details
command=$(get_command)

# Check if this is PostToolUse with a response
if is_post_tool_use && is_command_successful; then
    # Track test executions
    case "$command" in
        *"npm test"*|*"npm run test"*)
            log_hook_event "INFO" "Running unit tests (npm)"
            ;;
        *"pytest"*|*"python -m pytest"*)
            log_hook_event "INFO" "Running unit tests (pytest)"
            ;;
        *"cargo test"*)
            log_hook_event "INFO" "Running unit tests (cargo)"
            ;;
        *"go test"*)
            log_hook_event "INFO" "Running unit tests (go)"
            ;;
        *"mvn test"*|*"gradle test"*)
            log_hook_event "INFO" "Running unit tests (Java)"
            ;;
        *"rspec"*|*"bundle exec rspec"*)
            log_hook_event "INFO" "Running unit tests (RSpec)"
            ;;
    esac
    
    # Track integration tests
    if [[ "$command" =~ (integration|e2e|end-to-end) ]]; then
        log_hook_event "INFO" "Running integration tests"
    fi
    
    # Track TUI tests
    if [[ "$command" =~ tui-test ]]; then
        log_hook_event "INFO" "Running user simulation tests (TUI Test)"
    fi
    
    # Track test creation
    if [[ "$command" =~ mkdir.*test ]]; then
        log_hook_event "INFO" "Creating test structure"
    fi
    
    # Track coverage
    if [[ "$command" =~ coverage ]]; then
        log_hook_event "INFO" "Running test coverage analysis"
    fi
fi
