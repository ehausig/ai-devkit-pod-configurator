#!/bin/bash
# Testing framework for event-driven persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters - declare globally
declare -g TESTS_RUN=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0

# Test journal location - make it unique per test suite
TEST_JOURNAL="/tmp/test-journal-$$-${RANDOM}.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Kill any processes that might interfere with tests
kill_test_processes() {
  # Kill any existing monitors or actors
  pkill -f es-event-monitor.sh 2>/dev/null || true
  pkill -f "architect-actor.sh" 2>/dev/null || true
  pkill -f "developer-actor.sh" 2>/dev/null || true
  pkill -f "qa-actor.sh" 2>/dev/null || true
  pkill -f "reviewer-actor.sh" 2>/dev/null || true
  pkill -f "merger-actor.sh" 2>/dev/null || true
  pkill -f "test-.*-actor.sh" 2>/dev/null || true
  
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

# Assert functions
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
}

# Test runner with timeout protection - FIXED to handle edge cases
run_test_with_timeout() {
  local test_func="$1"
  local timeout="${2:-60}"  # Default timeout 60 seconds
  
  # Create temporary file for counter communication
  local counter_file="/tmp/test-counters-$$-$test_func"
  echo "TESTS_RUN=0" > "$counter_file"
  echo "TESTS_PASSED=0" >> "$counter_file"
  echo "TESTS_FAILED=0" >> "$counter_file"
  
  # Run test in background with counter file
  (
    # Set up error handling
    set +e
    
    # Source counter file to get initial values
    source "$counter_file"
    
    # Export counters so assert functions can use them
    export TESTS_RUN TESTS_PASSED TESTS_FAILED
    
    # Set up signal handler to save counters on exit
    save_counters() {
      echo "TESTS_RUN=$TESTS_RUN" > "$counter_file"
      echo "TESTS_PASSED=$TESTS_PASSED" >> "$counter_file"
      echo "TESTS_FAILED=$TESTS_FAILED" >> "$counter_file"
    }
    trap save_counters EXIT
    
    # Run the test function
    $test_func
  ) &
  local test_pid=$!
  
  # Wait for test with timeout
  local count=0
  while kill -0 $test_pid 2>/dev/null && [ $count -lt $timeout ]; do
    sleep 1
    ((count++))
  done
  
  # Check if test is still running
  if kill -0 $test_pid 2>/dev/null; then
    # Test timed out
    echo -e "${RED}✗${NC} Test timed out after ${timeout}s"
    kill -TERM $test_pid 2>/dev/null
    sleep 1
    kill -KILL $test_pid 2>/dev/null
    wait $test_pid 2>/dev/null
    
    # Clean up counter file
    rm -f "$counter_file"
    return 1
  else
    # Test completed, get exit code
    wait $test_pid
    local exit_code=$?
    
    # Source counter file to get final counts
    if [ -f "$counter_file" ]; then
      source "$counter_file"
      rm -f "$counter_file"
    fi
    
    return $exit_code
  fi
}

# Test runner - FIXED to handle function detection better
run_tests() {
  echo -e "${BLUE}Running tests...${NC}"
  echo ""

  # Initialize cumulative counters
  local TOTAL_RUN=0
  local TOTAL_PASSED=0
  local TOTAL_FAILED=0
  local TEST_FAILURES=0

  # Kill any interfering processes before starting tests
  kill_test_processes

  # Find all test functions in the current script
  # Use a more reliable method to find functions
  local test_functions=""
  
  # Method 1: Try using declare -F
  if declare -F >/dev/null 2>&1; then
    test_functions=$(declare -F | grep "^declare -f test_" | awk '{print $3}')
  fi
  
  # Method 2: If declare -F didn't work, try parsing the script
  if [ -z "$test_functions" ]; then
    # Get the current script name
    local current_script="${BASH_SOURCE[1]}"
    if [ -f "$current_script" ]; then
      # Extract function names from the script
      test_functions=$(grep -E "^test_[a-zA-Z0-9_]+\(\)" "$current_script" | sed 's/().*//')
    fi
  fi
  
  # Method 3: If still no functions found, check if we're in a sourced context
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

  for test_func in $test_functions; do
    echo -e "${YELLOW}Running $test_func${NC}"
    
    # Kill processes between tests
    kill_test_processes
    
    # Create fresh journal for each test
    local old_journal="$TEST_JOURNAL"
    TEST_JOURNAL="/tmp/test-journal-$$-${RANDOM}.md"
    export JOURNAL_FILE="$TEST_JOURNAL"
    
    # Setup test environment
    setup_test
    
    # Reset individual test counters
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    
    # Check if function exists before running
    if type -t "$test_func" >/dev/null 2>&1; then
      # Run the test with timeout protection
      if run_test_with_timeout "$test_func"; then
        : # Test passed
      else
        # Test function itself failed (not assertions)
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        ((TEST_FAILURES++))
      fi
    else
      echo -e "${RED}✗${NC} Test function not found: $test_func"
      ((TESTS_RUN++))
      ((TESTS_FAILED++))
      ((TEST_FAILURES++))
    fi
    
    # Accumulate counts
    TOTAL_RUN=$((TOTAL_RUN + TESTS_RUN))
    TOTAL_PASSED=$((TOTAL_PASSED + TESTS_PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + TESTS_FAILED))
    
    # Teardown
    teardown_test
    
    # Clean up this test's journal
    rm -f "$TEST_JOURNAL"
    TEST_JOURNAL="$old_journal"
    export JOURNAL_FILE="$TEST_JOURNAL"
    echo ""
  done

  # Final cleanup
  kill_test_processes

  # Summary with cumulative counts
  echo -e "${BLUE}Test Summary${NC}"
  echo -e "Tests run:    $TOTAL_RUN"
  echo -e "Tests passed: ${GREEN}$TOTAL_PASSED${NC}"
  echo -e "Tests failed: ${RED}$TOTAL_FAILED${NC}"

  if [ $TOTAL_FAILED -eq 0 ] && [ $TEST_FAILURES -eq 0 ]; then
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
