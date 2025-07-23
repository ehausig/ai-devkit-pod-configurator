#!/bin/bash
# Utilities for testing actors

# Load an actor in test mode
load_actor_for_test() {
    local actor_name="$1"
    export TEST_MODE=1
    export ACTOR_RUNTIME_MODE="test"
    
    # Source the actor
    source "/usr/local/bin/${actor_name}-actor.sh"
    
    # Verify it loaded correctly
    if [ "$ACTOR_RUNTIME_MODE" != "test" ]; then
        echo "Failed to load $actor_name in test mode" >&2
        return 1
    fi
    
    return 0
}

# Simulate work assignment and execution
simulate_work_execution() {
    local persona="$1"
    local work_id="$2"
    local work_desc="$3"
    
    # Emit work assigned event
    es-event-emit.sh "WORK_ASSIGNED" "TO:$persona|ID:$work_id|WORK:$work_desc"
    
    # Execute the work
    test_execute_work "$work_id" "$work_desc"
    
    # Check result
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        es-event-emit.sh "WORK_COMPLETED" "PERSONA:$persona|WORK_ID:$work_id"
    else
        es-event-emit.sh "WORK_FAILED" "PERSONA:$persona|WORK_ID:$work_id|REASON:$exit_code"
    fi
    
    return $exit_code
}

# Verify persona state
verify_persona_state() {
    local expected_state="$1"
    local actual_state=$(es-projection.sh "$PERSONA" "current_state")
    
    if [ "$actual_state" = "$expected_state" ]; then
        return 0
    else
        echo "State mismatch: expected $expected_state, got $actual_state" >&2
        return 1
    fi
}

# Create test actor wrapper for integration tests
create_test_actor_wrapper() {
    local persona="$1"
    local actor_name="$(echo $persona | tr '[:upper:]' '[:lower:]')-actor.sh"
    local wrapper_dir="/tmp/test-actors-$$"
    
    mkdir -p "$wrapper_dir"
    
    cat > "$wrapper_dir/$actor_name" << EOF
#!/bin/bash
# Test wrapper for $actor_name
export TEST_MODE=1
export TEST_JOURNAL="${TEST_JOURNAL:-/tmp/test-journal-$$.md}"
export JOURNAL_FILE="\$TEST_JOURNAL"
export ACTOR_RUNTIME_MODE="test"

# Add test mode indicator
echo "Test wrapper: Starting $actor_name in test mode" >&2

# Execute the real actor with test flag
exec /usr/local/bin/$actor_name --test-harness "\$@"
EOF
    
    chmod +x "$wrapper_dir/$actor_name"
    
    # Put wrapper first in PATH
    export PATH="$wrapper_dir:$PATH"
}

# Initialize test environment for actors
init_actor_test_env() {
    # Set test mode
    export TEST_MODE=1
    export ACTOR_RUNTIME_MODE="test"
    
    # Create test journal if not exists
    if [ -z "$TEST_JOURNAL" ]; then
        export TEST_JOURNAL="/tmp/test-journal-$$.md"
    fi
    export JOURNAL_FILE="$TEST_JOURNAL"
    
    # Ensure journal exists
    if [ ! -f "$TEST_JOURNAL" ]; then
        echo "# Test Journal" > "$TEST_JOURNAL"
        echo "" >> "$TEST_JOURNAL"
    fi
    
    # Kill any existing processes
    pkill -f es-event-monitor.sh 2>/dev/null || true
    pkill -f "actor.sh" 2>/dev/null || true
    
    # Clean up PID files
    rm -f /tmp/es-event-monitor.pid
    rm -f /tmp/es-event-monitor.lastline
    rm -rf /tmp/es-personas/
}

# Clean up after actor tests
cleanup_actor_test_env() {
    # Remove test journals
    rm -f /tmp/test-journal-*.md
    
    # Remove test actor wrappers
    rm -rf /tmp/test-actors-*
    
    # Kill any remaining test processes
    pkill -f "test-journal-" 2>/dev/null || true
    
    # Remove PID files
    rm -f /tmp/es-event-monitor.pid
    rm -f /tmp/es-event-monitor.lastline
    rm -rf /tmp/es-personas/
}

# Test helper to run actor work and verify output
test_actor_work() {
    local persona="$1"
    local work_desc="$2"
    local expected_outcome="$3"
    
    # Generate work ID
    local work_id="test-$(date +%s)-$$"
    
    # Execute work
    execute_persona_work "$work_id" "$work_desc"
    local exit_code=$?
    
    # Check outcome
    case "$expected_outcome" in
        success)
            if [ $exit_code -eq 0 ]; then
                return 0
            else
                echo "Expected success but got exit code $exit_code" >&2
                return 1
            fi
            ;;
        failure)
            if [ $exit_code -ne 0 ]; then
                return 0
            else
                echo "Expected failure but got success" >&2
                return 1
            fi
            ;;
        *)
            echo "Unknown expected outcome: $expected_outcome" >&2
            return 1
            ;;
    esac
}

# Export all utilities
export -f load_actor_for_test
export -f simulate_work_execution
export -f verify_persona_state
export -f create_test_actor_wrapper
export -f init_actor_test_env
export -f cleanup_actor_test_env
export -f test_actor_work
