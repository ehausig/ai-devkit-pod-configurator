#!/bin/bash
# Base actor functionality - source this in each persona actor
# Provides the core event loop and work execution framework

# Detect execution mode
if [ "$TEST_MODE" = "1" ]; then
    export ACTOR_RUNTIME_MODE="test"
    echo "es-actor-base.sh: TEST_MODE detected - using test runtime mode" >&2
else
    export ACTOR_RUNTIME_MODE="production"
fi

# Exit early if in test mode to prevent side effects
if [ "$TEST_MODE" = "1" ]; then
    # Define minimal interface for tests
    ACTOR_PID=$$
    ACTOR_ACTIVE=true
    
    # Mock functions that tests expect
    actor_loop() { 
        local PERSONA="$1"
        
        if [ "$ACTOR_RUNTIME_MODE" = "test" ]; then
            # In test mode, just set up the persona but don't loop
            echo "Test mode: Initializing $PERSONA actor without event loop" >&2
            ACTOR_PERSONA="$PERSONA"
            initialize_persona
            return 0
        fi
        
        # This should not be reached in test mode
        echo "ERROR: actor_loop called in test mode - this should not happen" >&2
        return 1
    }
    
    cleanup_actor() { 
        ACTOR_ACTIVE=false
    }
    
    should_handoff() {
        [ $(es-projection.sh "$PERSONA" "pending_work" | wc -l) -eq 0 ]
    }
    
    perform_handoff() {
        echo "Mock handoff from $1"
    }
    
    execute_command() {
        echo "Mock executing: $1"
        return 0
    }
    
    create_file_with_content() {
        mkdir -p "$(dirname "$1")"
        echo "$2" > "$1"
    }
    
    ensure_git_repo() {
        if [ ! -d .git ]; then
            git init >/dev/null 2>&1
            git config user.name "Test" >/dev/null 2>&1
            git config user.email "test@test.com" >/dev/null 2>&1
        fi
    }
    
    run_tests() {
        return 0
    }
    
    # Default persona implementations
    initialize_persona() { :; }
    determine_next_persona() { echo "COMPLETE"; }
    generate_work_items() { echo "Mock work item"; }
    execute_persona_work() { echo "Mock executing work: $2"; return 0; }
    
    # Logging functions
    log_decision() { echo "$(date -Iseconds) [$PERSONA:DECISION] $1" >> "$JOURNAL_FILE"; }
    log_issue() { echo "$(date -Iseconds) [$PERSONA:ISSUE] $1" >> "$JOURNAL_FILE"; }
    log_memory() { echo "$(date -Iseconds) [$PERSONA:MEMORY] $1" >> "$JOURNAL_FILE"; }
    log_context() { echo "$(date -Iseconds) [$PERSONA:CONTEXT] $1" >> "$JOURNAL_FILE"; }
    log_work_success() { :; }
    log_work_failure() { :; }
    log_handoff_context() { :; }
    
    # Export test helpers
    if [ "$ACTOR_RUNTIME_MODE" = "test" ]; then
        # Test mode: Export functions for direct testing
        export -f execute_persona_work
        export -f determine_next_persona
        export -f generate_work_items
        export -f initialize_persona
        export -f log_decision
        export -f log_issue
        export -f log_memory
        export -f log_context
        
        # Test helper to manually trigger work
        test_execute_work() {
            local work_id="$1"
            local work_desc="$2"
            execute_persona_work "$work_id" "$work_desc"
        }
        export -f test_execute_work
    fi
    
    # Don't set traps or do any initialization in test mode
    return 0
fi

# PRODUCTION MODE ONLY BELOW THIS POINT

# Ensure we have access to event sourcing utilities
export PATH="/usr/local/bin:$PATH"

# Set JOURNAL_FILE if not already set
export JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"

# Actor state
ACTOR_PID=$$
ACTOR_ACTIVE=true

# Cleanup on exit
cleanup_actor() {
    ACTOR_ACTIVE=false
}
trap cleanup_actor EXIT INT TERM

# Main actor loop
actor_loop() {
    local PERSONA="$1"
    
    echo "Starting $PERSONA actor (PID: $$)"
    es-event-emit.sh "PERSONA_ACTIVATED" "PERSONA:$PERSONA|PID:$$"
    
    # Initialize persona-specific context
    initialize_persona
    
    while $ACTOR_ACTIVE; do
        # Get next work item
        local next_work=$(es-projection.sh "$PERSONA" "next_work")
        
        if [ -n "$next_work" ]; then
            # Extract work details
            if [[ "$next_work" =~ ID:([^|]+) ]]; then
                local work_id="${BASH_REMATCH[1]}"
                local work_desc=$(es-projection.sh "$PERSONA" "work_description" "$work_id")
                
                echo "[$PERSONA] Starting work: $work_desc"
                es-event-emit.sh "WORK_STARTED" "PERSONA:$PERSONA|WORK_ID:$work_id"
                
                # Execute persona-specific work
                if execute_persona_work "$work_id" "$work_desc"; then
                    echo "[$PERSONA] Completed work: $work_id"
                    es-event-emit.sh "WORK_COMPLETED" "PERSONA:$PERSONA|WORK_ID:$work_id"
                    
                    # Log success if persona implements it
                    if type log_work_success >/dev/null 2>&1; then
                        log_work_success "$work_id" "$work_desc"
                    fi
                else
                    echo "[$PERSONA] Failed work: $work_id"
                    es-event-emit.sh "WORK_FAILED" "PERSONA:$PERSONA|WORK_ID:$work_id|REASON:$?"
                    
                    # Log failure if persona implements it
                    if type log_work_failure >/dev/null 2>&1; then
                        log_work_failure "$work_id" "$work_desc" "$?"
                    fi
                fi
            fi
        else
            # No pending work - check if ready for handoff
            if should_handoff; then
                echo "[$PERSONA] Ready for handoff"
                perform_handoff "$PERSONA"
                break
            else
                # Wait for more work
                sleep 2
            fi
        fi
        
        # Small delay between work items
        sleep 1
    done
    
    echo "[$PERSONA] Going idle"
    es-event-emit.sh "PERSONA_IDLE" "PERSONA:$PERSONA"
}

# Check if persona should hand off
should_handoff() {
    # Default: handoff when no pending work
    local pending=$(es-projection.sh "$PERSONA" "pending_work" | wc -l)
    [ "$pending" -eq 0 ]
}

# Perform handoff to next persona
perform_handoff() {
    local from_persona="$1"
    
    # Determine next persona and reason
    local handoff_decision=$(determine_next_persona "$from_persona")
    local next_persona=$(echo "$handoff_decision" | cut -d: -f1)
    local reason=$(echo "$handoff_decision" | cut -d: -f2-)
    
    if [ "$next_persona" = "COMPLETE" ]; then
        echo "[$from_persona] Development cycle complete"
        es-event-emit.sh "CYCLE_COMPLETE" "FINAL_PERSONA:$from_persona"
    else
        echo "[$from_persona] Handing off to $next_persona ($reason)"
        es-event-emit.sh "HANDOFF_INITIATED" "FROM:$from_persona|REASON:$reason"
        
        # Generate work items for next persona
        echo "[$from_persona] Creating work items for $next_persona"
        local work_count=0
        generate_work_items "$from_persona" "$next_persona" | while IFS= read -r work; do
            if [ -n "$work" ]; then
                local work_id="$(date +%s)-$$-$((++work_count))"
                es-event-emit.sh "WORK_ASSIGNED" "TO:$next_persona|ID:$work_id|WORK:$work"
                echo "  → Assigned: $work"
            fi
        done
        
        # Emit handoff ready event
        es-event-emit.sh "HANDOFF_READY" "FROM:$from_persona|TO:$next_persona|COUNT:$work_count"
        
        # Log handoff context
        if type log_handoff_context >/dev/null 2>&1; then
            log_handoff_context "$next_persona" "$reason"
        fi
    fi
}

# Shared work execution utilities
execute_command() {
    local cmd="$1"
    local description="${2:-Executing command}"
    
    echo "  → $description"
    if eval "$cmd"; then
        return 0
    else
        local exit_code=$?
        echo "  ✗ Command failed with exit code $exit_code"
        return $exit_code
    fi
}

# File creation utility
create_file_with_content() {
    local filepath="$1"
    local content="$2"
    
    mkdir -p "$(dirname "$filepath")"
    echo "$content" > "$filepath"
    echo "  → Created $filepath"
}

# Git utilities
ensure_git_repo() {
    if [ ! -d .git ]; then
        git init
        git config user.name "AI Developer"
        git config user.email "ai@devkit.local"
        echo "  → Initialized git repository"
    fi
}

# Testing utilities
run_tests() {
    local test_type="${1:-unit}"
    
    if [ -f "package.json" ]; then
        npm test
    elif [ -f "Cargo.toml" ]; then
        cargo test
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        python -m pytest tests/ -v
    elif [ -f "go.mod" ]; then
        go test ./...
    else
        echo "  → No test framework detected"
        return 0
    fi
}

# Default implementations (override in specific actors)
initialize_persona() {
    # Persona-specific initialization
    true
}

determine_next_persona() {
    # Return "COMPLETE" to end cycle, or "PERSONA:reason" to continue
    echo "COMPLETE"
}

generate_work_items() {
    # Generate work items for next persona
    # Each line should be a work description
    true
}

execute_persona_work() {
    # Execute a specific work item
    # Return 0 on success, non-zero on failure
    echo "Warning: No work execution implemented for $PERSONA"
    return 1
}

# Logging utilities for personas
log_decision() {
    local decision="$1"
    echo "$(date -Iseconds) [$PERSONA:DECISION] $decision" >> "$JOURNAL_FILE"
}

log_issue() {
    local issue="$1"
    echo "$(date -Iseconds) [$PERSONA:ISSUE] $issue" >> "$JOURNAL_FILE"
}

log_memory() {
    local memory="$1"
    echo "$(date -Iseconds) [$PERSONA:MEMORY] $memory" >> "$JOURNAL_FILE"
}

log_context() {
    local context="$1"
    echo "$(date -Iseconds) [$PERSONA:CONTEXT] $context" >> "$JOURNAL_FILE"
}
