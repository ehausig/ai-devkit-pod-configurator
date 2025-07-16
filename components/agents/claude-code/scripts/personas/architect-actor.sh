#!/bin/bash
# ARCHITECT Actor - System design and planning persona

# Source the base actor functionality
source es-actor-base

# Persona name
PERSONA="ARCHITECT"

# Initialize ARCHITECT context
initialize_persona() {
    log_context "ARCHITECT persona initialized - ready for system design"
    
    # Check for any existing architecture documents
    if [ -f "ARCHITECTURE.md" ]; then
        log_memory "Found existing architecture document"
    fi
}

# Determine next persona based on work completed
determine_next_persona() {
    local from="$1"
    
    # Check if all design documents exist
    local docs_complete=true
    for doc in ARCHITECTURE.md API_DESIGN.md DATA_MODELS.md TESTING_STRATEGY.md; do
        if [ ! -f "$doc" ]; then
            docs_complete=false
            break
        fi
    done
    
    if [ "$docs_complete" = "true" ]; then
        echo "DEVELOPER:All design documents complete"
    else
        echo "COMPLETE:Missing design documents"
    fi
}

# Generate work items for next persona
generate_work_items() {
    local from="$1"
    local to="$2"
    
    if [ "$to" = "DEVELOPER" ]; then
        # Analyze architecture to create specific work items
        local project_type="unknown"
        local needs_api=false
        local needs_cli=false
        local needs_frontend=false
        
        # Detect project type from architecture
        if [ -f "ARCHITECTURE.md" ]; then
            grep -qi "api\|rest\|graphql" ARCHITECTURE.md && needs_api=true
            grep -qi "cli\|command.line" ARCHITECTURE.md && needs_cli=true
            grep -qi "frontend\|ui\|interface" ARCHITECTURE.md && needs_frontend=true
            grep -qi "python" ARCHITECTURE.md && project_type="python"
            grep -qi "node\|javascript" ARCHITECTURE.md && project_type="nodejs"
            grep -qi "rust" ARCHITECTURE.md && project_type="rust"
            grep -qi "go\|golang" ARCHITECTURE.md && project_type="go"
        fi
        
        # Create feature branch
        echo "Create feature branch feat/initial-implementation"
        echo "Initialize project with $project_type tooling"
        echo "Set up project structure with src/ and tests/ directories"
        
        # Core implementation tasks
        echo "Write failing tests for core data models"
        echo "Implement data models to pass tests"
        
        # API tasks if needed
        if [ "$needs_api" = "true" ]; then
            echo "Write failing tests for API endpoints"
            echo "Implement API endpoints to pass tests"
            echo "Add API documentation and examples"
        fi
        
        # CLI tasks if needed
        if [ "$needs_cli" = "true" ]; then
            echo "Write failing tests for CLI commands"
            echo "Implement CLI interface to pass tests"
            echo "Add CLI help and usage documentation"
        fi
        
        # Standard tasks
        echo "Implement comprehensive error handling"
        echo "Add logging and debugging capabilities"
        echo "Ensure minimum 80% test coverage"
        echo "Add README with setup instructions"
        echo "Create pull request when all tests pass"
    fi
}

# Execute ARCHITECT-specific work
execute_persona_work() {
    local work_id="$1"
    local work_desc="$2"
    
    case "$work_desc" in
        *"Create system architecture"*|*"system design"*|*"architecture document"*)
            log_decision "Creating system architecture document"
            create_file_with_content "ARCHITECTURE.md" "# System Architecture

## Overview
This document describes the high-level architecture of the system.

## Design Principles
- Modularity and separation of concerns
- Test-driven development
- Clear API boundaries
- Comprehensive error handling

## System Components
### Backend
- RESTful API service
- Data persistence layer
- Business logic modules

### Testing
- Unit tests for all modules
- Integration tests for API
- End-to-end tests for workflows

## Technology Stack
- Primary language: Python/Node.js/Rust/Go (TBD based on requirements)
- Testing framework: Language-appropriate
- API framework: Language-appropriate

## Deployment Architecture
- Containerized application
- Kubernetes-ready
- Environment-based configuration"
            
            log_memory "Architecture focuses on modularity and testability"
            return 0
            ;;
            
        *"API design"*|*"API specification"*)
            log_decision "Designing RESTful API specification"
            create_file_with_content "API_DESIGN.md" "# API Design Specification

## API Overview
RESTful API following standard conventions.

## Endpoints

### Health Check
- **GET** \`/health\`
- Response: \`{\"status\": \"healthy\", \"timestamp\": \"...\"}\`

### Core Resources
- **GET** \`/api/v1/resources\` - List resources
- **POST** \`/api/v1/resources\` - Create resource
- **GET** \`/api/v1/resources/{id}\` - Get resource
- **PUT** \`/api/v1/resources/{id}\` - Update resource
- **DELETE** \`/api/v1/resources/{id}\` - Delete resource

## Request/Response Formats
- Content-Type: application/json
- Authentication: Bearer token
- Error format: \`{\"error\": {\"code\": \"...\", \"message\": \"...\"}}\`

## Status Codes
- 200 OK - Success
- 201 Created - Resource created
- 400 Bad Request - Invalid input
- 401 Unauthorized - Authentication required
- 404 Not Found - Resource not found
- 500 Internal Server Error - Server error"
            
            log_memory "API follows RESTful conventions with standard error handling"
            return 0
            ;;
            
        *"data model"*|*"data structure"*|*"schema"*)
            log_decision "Defining data models and schemas"
            create_file_with_content "DATA_MODELS.md" "# Data Models

## Core Entities

### Resource Model
\`\`\`json
{
  \"id\": \"uuid\",
  \"name\": \"string\",
  \"description\": \"string\",
  \"created_at\": \"timestamp\",
  \"updated_at\": \"timestamp\",
  \"metadata\": {}
}
\`\`\`

## Validation Rules
- ID: UUID v4
- Name: Required, 1-255 characters
- Description: Optional, max 1000 characters
- Timestamps: ISO 8601 format

## Database Schema
- Primary key: id
- Indexes: name, created_at
- Constraints: name NOT NULL"
            
            log_memory "Data models use UUID identifiers and standard timestamps"
            return 0
            ;;
            
        *"testing strategy"*|*"test plan"*)
            log_decision "Creating comprehensive testing strategy"
            create_file_with_content "TESTING_STRATEGY.md" "# Testing Strategy

## Test Levels

### Unit Tests
- Test individual functions/methods
- Mock external dependencies
- Aim for 80% code coverage
- Fast execution (< 1 second per test)

### Integration Tests
- Test API endpoints
- Use real database (test instance)
- Verify data persistence
- Test error scenarios

### End-to-End Tests
- Test complete user workflows
- No mocking of services
- Verify system behavior

## Test Organization
- tests/unit/ - Unit tests
- tests/integration/ - Integration tests
- tests/e2e/ - End-to-end tests

## Continuous Testing
- Run unit tests on every commit
- Run integration tests before merge
- Run e2e tests on main branch

## Test Data Management
- Use factories for test data
- Clean database between tests
- Deterministic test data"
            
            log_memory "Testing strategy emphasizes TDD with 80% coverage target"
            return 0
            ;;
            
        *"review requirements"*|*"analyze project"*)
            log_decision "Analyzing project requirements"
            log_context "Understanding project scope and constraints"
            
            # This is where we'd analyze the actual requirements
            # For now, we'll assume standard web service requirements
            log_memory "Project requires a RESTful API with data persistence"
            return 0
            ;;
            
        *)
            log_issue "Unknown work type: $work_desc"
            return 1
            ;;
    esac
}

# Log successful work completion
log_work_success() {
    local work_id="$1"
    local work_desc="$2"
    log_context "Successfully completed: $work_desc"
}

# Log work failure
log_work_failure() {
    local work_id="$1"
    local work_desc="$2"
    local exit_code="$3"
    log_issue "Failed to complete: $work_desc (exit code: $exit_code)"
}

# Log handoff context
log_handoff_context() {
    local next_persona="$1"
    local reason="$2"
    log_context "Handing off to $next_persona - $reason"
    log_memory "Design phase complete, implementation can begin"
}

# Start the actor
actor_loop "$PERSONA"
