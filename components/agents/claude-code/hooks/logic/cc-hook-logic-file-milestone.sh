#!/bin/bash
# File milestone tracking hook logic
# Called by hook-framework.sh

if is_post_tool_use; then
    # Extract file path
    file_path=$(get_file_path)
    file_name=$(basename "$file_path")
    
    # Track significant file creations
    case "$file_name" in
        README.md|readme.md)
            log_hook_event "MILESTONE" "Project README created"
            ;;
        LICENSE|LICENSE.md|LICENSE.txt)
            log_hook_event "MILESTONE" "License file added"
            ;;
        .gitignore)
            log_hook_event "MILESTONE" "Git ignore rules configured"
            ;;
        Dockerfile|dockerfile)
            log_hook_event "MILESTONE" "Docker configuration added"
            ;;
        docker-compose.yml|docker-compose.yaml)
            log_hook_event "MILESTONE" "Docker Compose configuration added"
            ;;
        Makefile|makefile)
            log_hook_event "MILESTONE" "Build automation added (Makefile)"
            ;;
        .env.example|.env.template)
            log_hook_event "MILESTONE" "Environment configuration template created"
            ;;
        CHANGELOG.md|CHANGELOG.txt)
            log_hook_event "MILESTONE" "Changelog initialized"
            ;;
        CONTRIBUTING.md)
            log_hook_event "MILESTONE" "Contribution guidelines added"
            ;;
    esac
    
    # Track test file creation
    if [[ "$file_path" =~ test.*\.(py|js|ts|go|rs|java|rb)$ ]] || [[ "$file_path" =~ .*_test\.(py|js|ts|go|rs|java|rb)$ ]]; then
        log_hook_event "INFO" "Test file created: $file_name"
    fi
    
    # Track configuration files
    case "$file_path" in
        *.github/workflows/*.yml|*.github/workflows/*.yaml)
            workflow_name=$(basename "$file_path" .yml | basename "$file_path" .yaml)
            log_hook_event "MILESTONE" "GitHub Action workflow created: $workflow_name"
            ;;
        */.pre-commit-config.yaml)
            log_hook_event "MILESTONE" "Pre-commit hooks configured"
            ;;
        */tox.ini|*/setup.cfg|*/pyproject.toml)
            log_hook_event "MILESTONE" "Python project configuration added"
            ;;
        */tsconfig.json|*/jsconfig.json)
            log_hook_event "MILESTONE" "TypeScript/JavaScript configuration added"
            ;;
    esac
    
    # Track documentation
    if [[ "$file_path" =~ docs/.* ]] || [[ "$file_path" =~ .*\.md$ ]]; then
        log_hook_event "INFO" "Documentation updated: $file_name"
    fi
fi
