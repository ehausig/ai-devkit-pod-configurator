#!/bin/bash
# Testing framework for event-driven persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters - declare globally and export them
declare -g TESTS_RUN=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
export TESTS_RUN TESTS_PASSED TESTS_FAILED

# Test journal location - make it unique per test suite
TEST_JOURNAL="/tmp/test-journal-$$-${RANDOM}.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Kill any processes that might interfere with tests
kill_test_processes() {
  # Kill any existing monitors or actors
  pkill -f es-event-monitor.sh 2>/dev/null || true
  
  # Kill actor scripts ONLY if they're running as actual actors (not test scripts)
  # Use more specific patterns to avoid killing test scripts
  pkill -f "/usr/local/bin/architect-actor.sh" 2>/dev/null || true
  pkill -f "/usr/local/bin/developer-actor.sh" 2>/dev/null || true
  pkill -f "/usr/local/bin/qa-actor.sh" 2>/dev/null || true
  pkill -f "/usr/local/bin/reviewer-actor.sh" 2>/dev/null || true
  pkill -f "/usr/local/bin/merger-actor.sh" 2>/dev/null || true
  
  # Also kill any that might be running from test directories
  pkill -f "test-.*/architect-actor.sh" 2>/dev/null || true
  pkill -f "test-.*/developer-actor.sh" 2>/dev/null || true
  pkill -f "test-.*/qa-actor.sh" 2>/dev/null || true
  pkill -f "test-.*/reviewer-actor.sh" 2>/dev/null || true
  pkill -f "test-.*/merger-actor.sh" 2>/dev/null || true
  
  # Clean up PID files
  rm -f /tmp/es-event-monitor.pid
  rm -f /tmp/es-event-monitor.lastline
  rm -rf /tmp/es-personas/
  
  # Clean up test artifacts
  rm -f /tmp/architect-mock-*.pid
  rm -f /tmp/architect-run-count
  rm -f /tmp/architect-second-run
  rm -f /tmp/architect-has-run-once
  rm -f /tmp/architect-should-exit-quickly
  rm -f /tmp/architect-activation-count
  rm -f /tmp/monitor-*.log
  
  # Clean up test directories
  rm -rf /tmp/test-actors-*
  rm -rf /tmp/test-project-*
  rm -rf /tmp/test-handoff-*
  rm -rf /tmp/test-patterns-*
  rm -rf /tmp/test-format-*
  rm -rf /tmp/test-git-*
  rm -rf /tmp/test-multi-lang-*
  rm -rf /tmp/test-tools-*
  rm -rf /tmp/test-structure-*
  rm -rf /tmp/test-cicd-*
  rm -rf /tmp/test-env-*
  rm -rf /tmp/test-docs-*
  rm -rf /tmp/test-deps-*
  rm -rf /tmp/test-qa-*
  rm -rf /tmp/test-review-*
  rm -rf /tmp/test-merger-*
}

# Setup test environment
setup_test() {
  # Kill any interfering processes first
  kill_test_processes
  
  # Create clean test journal
  echo "# Test Journal" >"$TEST_JOURNAL"
  echo "" >>"$TEST_JOURNAL"

  # Set test mode for scripts
  export TEST_MODE=1
  export DEBUG=1
  
  # Save current directory
  export TEST_ORIGINAL_DIR="$PWD"
  
  # Small delay to ensure processes are dead
  sleep 0.5
}

# Teardown test environment
teardown_test() {
  # Return to original directory
  if [ -n "$TEST_ORIGINAL_DIR" ]; then
    cd "$TEST_ORIGINAL_DIR" 2>/dev/null || true
  fi
  
  # Clean up test journal
  rm -f "$TEST_JOURNAL"

  # Kill any test processes
  pkill -f "test-journal-$$" 2>/dev/null || true
  
  # Clean up test directories
  rm -rf /tmp/test-*-$$
}

# Assert functions - ensure they update global counters
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values should be equal}"

  ((TESTS_RUN++))
  if [ "$expected" = "$actual" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Expected: $expected"
    echo -e "  Actual:   $actual"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Should contain substring}"

  ((TESTS_RUN++))
  if echo "$haystack" | grep -q "$needle"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Looking for: $needle"
    echo -e "  In: $haystack"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Should not contain substring}"

  ((TESTS_RUN++))
  if echo "$haystack" | grep -q "$needle"; then
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Found: $needle"
    echo -e "  In: $haystack"
  else
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

assert_event_exists() {
  local event_type="$1"
  local message="${2:-Event should exist in journal}"

  ((TESTS_RUN++))
  if grep -q "TYPE:$event_type" "$TEST_JOURNAL"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Event type not found: $event_type"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Exit code should match}"

  ((TESTS_RUN++))
  if [ "$expected" -eq "$actual" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Expected exit code: $expected"
    echo -e "  Actual exit code:   $actual"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

assert_file_exists() {
  local filepath="$1"
  local message="${2:-File should exist}"

  ((TESTS_RUN++))
  if [ -f "$filepath" ] || [ -d "$filepath" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  File not found: $filepath"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

# New assertion helper to avoid counting issues
assert_work_executed() {
  local exit_code="$1"
  local work_desc="$2"
  
  ((TESTS_RUN++))
  if [ "$exit_code" -eq 0 ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} Work executed: $work_desc"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} Work failed: $work_desc (exit code: $exit_code)"
  fi
  
  # Export updated counters
  export TESTS_RUN TESTS_PASSED TESTS_FAILED
}

# Test runner - simplified to avoid counter issues
run_tests() {
  echo -e "${BLUE}Running tests...${NC}"
  echo ""

  # Reset ALL counters at the start and export them
  TESTS_RUN=0
  TESTS_PASSED=0
  TESTS_FAILED=0
  export TESTS_RUN TESTS_PASSED TESTS_FAILED

  # Kill any interfering processes before starting tests
  kill_test_processes

  # Find all test functions in the current script
  local test_functions=""
  
  # Get the current script name
  local current_script="${BASH_SOURCE[1]}"
  if [ -f "$current_script" ]; then
    # Extract function names from the script
    test_functions=$(grep -E "^test_[a-zA-Z0-9_]+\(\)" "$current_script" | sed 's/().*//')
  fi
  
  # If no test functions found, try other methods
  if [ -z "$test_functions" ]; then
    # List all functions and filter test functions
    test_functions=$(compgen -A function | grep "^test_" || true)
  fi

  # If no test functions found, report error
  if [ -z "$test_functions" ]; then
    echo -e "${RED}No test functions found!${NC}"
    echo "Make sure test functions are defined as: test_function_name() { ... }"
    return 1
  fi

  # Count test functions for debugging
  local num_test_functions=$(echo "$test_functions" | wc -w)
  echo "Found $num_test_functions test functions"
  echo ""

  for test_func in $test_functions; do
    echo -e "${YELLOW}Running $test_func${NC}"
    
    # Kill processes between tests
    kill_test_processes
    
    # Create fresh journal for each test
    TEST_JOURNAL="/tmp/test-journal-$$-${RANDOM}.md"
    export JOURNAL_FILE="$TEST_JOURNAL"
    
    # Setup test environment
    setup_test
    
    # Check if function exists before running
    if type -t "$test_func" >/dev/null 2>&1; then
      # Run the test function directly (no timeout for simplicity)
      $test_func
    else
      echo -e "${RED}✗${NC} Test function not found: $test_func"
      ((TESTS_RUN++))
      ((TESTS_FAILED++))
    fi
    
    # Teardown
    teardown_test
    
    # Clean up this test's journal
    rm -f "$TEST_JOURNAL"
    echo ""
  done

  # Final cleanup
  kill_test_processes

  # Summary
  echo -e "${BLUE}Test Summary${NC}"
  echo -e "Tests run:    $TESTS_RUN"
  echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "\n${RED}Some tests failed!${NC}"
    return 1
  fi
}

# Utility to wait for event
wait_for_event() {
  local event_pattern="$1"
  local timeout="${2:-5}"
  local elapsed=0

  while [ $elapsed -lt $timeout ]; do
    if grep -q "$event_pattern" "$TEST_JOURNAL" 2>/dev/null; then
      return 0
    fi
    sleep 0.5
    ((elapsed++))
  done

  return 1
}

# Mock actor for testing
create_mock_actor() {
  local persona="$1"
  cat >"/tmp/test-${persona,,}-actor-$$.sh" <<EOF
#!/bin/bash
echo "Mock $persona actor started"
es-event-emit.sh "PERSONA_ACTIVATED" "PERSONA:$persona|PID:\$\$"
sleep 1
es-event-emit.sh "PERSONA_IDLE" "PERSONA:$persona"
EOF
  chmod +x "/tmp/test-${persona,,}-actor-$$.sh"
}

# Cleanup mock actors
cleanup_mock_actors() {
  rm -f /tmp/test-*-actor-$$.sh
  rm -f /tmp/test-*-actor-*.sh
}

# Mock tool operation helper
emit_mock_tool_event() {
  local tool="$1"
  local operation="$2"
  local result="${3:-success}"
  local persona="${4:-${PERSONA:-UNKNOWN}}"
  
  echo "$(date -Iseconds) [${persona}:TOOL] $tool operation: $operation (result: $result)" >> "$JOURNAL_FILE"
  
  # Also emit as structured event if needed
  if [ "$result" = "success" ]; then
    es-event-emit.sh "TOOL_OPERATION" "PERSONA:$persona|TOOL:$tool|OP:$operation|RESULT:success" 2>/dev/null || true
  else
    es-event-emit.sh "TOOL_OPERATION" "PERSONA:$persona|TOOL:$tool|OP:$operation|RESULT:failure|ERROR:$result" 2>/dev/null || true
  fi
}

# Mock git operations
mock_git_operation() {
  local operation="$1"
  local details="$2"
  local persona="${3:-${PERSONA:-UNKNOWN}}"
  
  echo "$(date -Iseconds) [${persona}:GIT] $operation: $details" >> "$JOURNAL_FILE"
  return 0
}

# Mock command execution for tests
mock_execute_command() {
  local cmd="$1"
  local description="${2:-Executing command}"
  local persona="${3:-${PERSONA:-UNKNOWN}}"
  
  echo "$(date -Iseconds) [${persona}:MOCK] Would execute: $cmd" >> "$JOURNAL_FILE"
  echo "  → $description"
  
  # Always return success in test mode
  return 0
}

# Export all assert functions so they're available in sourced contexts
export -f assert_equals
export -f assert_contains
export -f assert_not_contains
export -f assert_event_exists
export -f assert_exit_code
export -f assert_file_exists
export -f assert_work_executed

# Export other test utilities
export -f wait_for_event
export -f create_mock_actor
export -f cleanup_mock_actors
export -f emit_mock_tool_event
export -f mock_git_operation
export -f mock_execute_command
