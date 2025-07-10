#!/bin/bash
# Technical decision tracking hook logic
# Called by hook-framework.sh

if is_post_tool_use; then
    # PostToolUse - file was written
    file_path=$(get_file_path)
    content=$(extract_json_field "$JSON_INPUT" '.tool_input.content')
    
    # Detect project type based on file
    case "$file_path" in
        */package.json)
            log_hook_event "DECISION" "Project type: Node.js/JavaScript chosen"
            ;;
        */requirements.txt|*/setup.py|*/pyproject.toml)
            log_hook_event "DECISION" "Project type: Python chosen"
            ;;
        */Cargo.toml)
            log_hook_event "DECISION" "Project type: Rust chosen"
            ;;
        */go.mod)
            log_hook_event "DECISION" "Project type: Go chosen"
            ;;
        */pom.xml|*/build.gradle)
            log_hook_event "DECISION" "Project type: Java chosen"
            ;;
        */Gemfile)
            log_hook_event "DECISION" "Project type: Ruby chosen"
            ;;
    esac
    
    # Detect frameworks/libraries from content
    if [[ -n "$content" ]]; then
        # Web frameworks
        if echo "$content" | grep -qE "(express|fastapi|flask|gin|actix|rails|spring)"; then
            framework=$(echo "$content" | grep -oE "(express|fastapi|flask|gin|actix|rails|spring)" | head -1)
            log_hook_event "DECISION" "Web framework: $framework chosen"
        fi
        
        # Testing frameworks
        if echo "$content" | grep -qE "(jest|pytest|cargo test|go test|junit|rspec)"; then
            test_framework=$(echo "$content" | grep -oE "(jest|pytest|cargo test|go test|junit|rspec)" | head -1)
            log_hook_event "DECISION" "Testing framework: $test_framework chosen"
        fi
        
        # Database decisions
        if echo "$content" | grep -qE "(postgres|mysql|mongodb|redis|sqlite)"; then
            database=$(echo "$content" | grep -oE "(postgres|mysql|mongodb|redis|sqlite)" | head -1)
            log_hook_event "DECISION" "Database: $database chosen"
        fi
    fi
    
    # Architecture files
    case "$file_path" in
        */Dockerfile)
            log_hook_event "DECISION" "Containerization: Docker chosen"
            ;;
        */.github/workflows/*.yml|*/.github/workflows/*.yaml)
            log_hook_event "DECISION" "CI/CD: GitHub Actions configured"
            ;;
        */docker-compose.yml|*/docker-compose.yaml)
            log_hook_event "DECISION" "Multi-container setup: Docker Compose configured"
            ;;
    esac
fi
