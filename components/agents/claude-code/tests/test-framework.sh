#!/bin/bash
# Testing framework for event-driven persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters - declare but don't initialize here
declare -g TESTS_RUN
declare -g TESTS_PASSED
declare -g TESTS_FAILED

# Test journal location - make it unique per test suite
TEST_JOURNAL="/tmp/test-journal-$-${RANDOM}.md"
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
  
  # Small delay to ensure processes are dead
  sleep 0.5
}

# Teardown test environment
teardown_test() {
  # Clean up test journal
  rm -f "$TEST_JOURNAL"

  # Kill any test processes
  pkill -f "test-journal-$" 2>/dev/null || true
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
  if [ -f "$filepath" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $message"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $message"
    echo -e "  File not found: $filepath"
  fi
}

# Test runner
run_tests() {
  echo -e "${BLUE}Running tests...${NC}"
  echo ""

  # Reset counters for this test file
  TESTS_RUN=0
  TESTS_PASSED=0
  TESTS_FAILED=0

  # Kill any interfering processes before starting tests
  kill_test_processes

  # Find and run all test functions
  local test_functions=$(declare -F | grep "^declare -f test_" | awk '{print $3}')

  for test_func in $test_functions; do
    echo -e "${YELLOW}Running $test_func${NC}"
    
    # Kill processes between tests
    kill_test_processes
    
    # Create fresh journal for each test
    local old_journal="$TEST_JOURNAL"
    TEST_JOURNAL="/tmp/test-journal-$-${RANDOM}.md"
    export JOURNAL_FILE="$TEST_JOURNAL"
    
    # Setup test environment
    setup_test
    
    # Run the test
    $test_func
    
    # Clean up this test's journal
    rm -f "$TEST_JOURNAL"
    TEST_JOURNAL="$old_journal"
    export JOURNAL_FILE="$TEST_JOURNAL"
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
  cat >"/tmp/test-${persona,,}-actor-$.sh" <<EOF
#!/bin/bash
echo "Mock $persona actor started"
es-event-emit.sh "PERSONA_ACTIVATED" "PERSONA:$persona|PID:\$\$"
sleep 1
es-event-emit.sh "PERSONA_IDLE" "PERSONA:$persona"
EOF
  chmod +x "/tmp/test-${persona,,}-actor-$.sh"
}

# Cleanup mock actors
cleanup_mock_actors() {
  rm -f /tmp/test-*-actor-$.sh
  rm -f /tmp/test-*-actor-*.sh
}
