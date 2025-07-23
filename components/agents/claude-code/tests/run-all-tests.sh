#!/bin/bash
# Run all tests for the event-driven persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Find test directory - check multiple locations
if [ -d "$HOME/.claude/tests" ]; then
    TEST_DIR="$HOME/.claude/tests"
elif [ -d "$(dirname "$0")" ] && [ -f "$(dirname "$0")/test-framework.sh" ]; then
    TEST_DIR="$(dirname "$0")"
else
    echo -e "${RED}Error: Cannot find test directory${NC}"
    echo "Looked in: $HOME/.claude/tests and $(dirname "$0")"
    exit 1
fi

# Change to test directory
cd "$TEST_DIR"

# Ensure scripts are in PATH
export PATH="/usr/local/bin:$PATH"

# Kill any existing processes from previous test runs
kill_existing_processes() {
  echo "Cleaning up any existing processes..."
  
  # Kill any existing event monitors
  pkill -f es-event-monitor.sh 2>/dev/null || true
  
  # Kill any existing persona actors
  pkill -f "architect-actor" 2>/dev/null || true
  pkill -f "developer-actor" 2>/dev/null || true
  pkill -f "qa-actor" 2>/dev/null || true
  pkill -f "reviewer-actor" 2>/dev/null || true
  pkill -f "merger-actor" 2>/dev/null || true
  
  # Kill any test processes
  pkill -f "test-journal-" 2>/dev/null || true
  pkill -f "test-.*-actor" 2>/dev/null || true
  
  # Wait for processes to die
  sleep 2
  
  # Force kill any stubborn processes
  pkill -9 -f es-event-monitor 2>/dev/null || true
  pkill -9 -f "actor" 2>/dev/null || true
  
  # Remove PID files and directories
  rm -f /tmp/es-event-monitor.pid
  rm -f /tmp/es-event-monitor.lastline
  rm -rf /tmp/es-personas/
  rm -rf /tmp/test-actors-*
  rm -f /tmp/architect-actor-*.running
  rm -f /tmp/architect-mock-*.pid
  rm -f /tmp/architect-run-count
  rm -f /tmp/architect-second-run
  rm -f /tmp/architect-has-run-once
  rm -f /tmp/architect-should-exit-quickly
  rm -f /tmp/architect-activation-count
  rm -f /tmp/monitor-*.log
  
  # Clean test journals
  rm -f /tmp/test-journal-*.md
}

# Backup and create fresh journal
setup_fresh_journal() {
  # Backup existing journal if it exists
  if [ -f "$HOME/workspace/JOURNAL.md" ]; then
    cp "$HOME/workspace/JOURNAL.md" "$HOME/workspace/JOURNAL.md.backup-$(date +%s)"
  fi
  
  # Create fresh journal for testing
  echo "# Development Journal - Test Run $(date)" > "$HOME/workspace/JOURNAL.md"
  echo "" >> "$HOME/workspace/JOURNAL.md"
}

# Restore journal after tests
restore_journal() {
  # Find most recent backup
  local latest_backup=$(ls -t "$HOME/workspace/JOURNAL.md.backup-"* 2>/dev/null | head -1)
  
  if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
    mv "$latest_backup" "$HOME/workspace/JOURNAL.md"
    # Clean up other backups older than 1 hour
    find "$HOME/workspace" -name "JOURNAL.md.backup-*" -mmin +60 -delete 2>/dev/null || true
  fi
}

# Cleanup function
cleanup() {
  echo -e "\n${BLUE}Cleaning up test environment...${NC}"
  kill_existing_processes
  restore_journal
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Initial cleanup
kill_existing_processes
setup_fresh_journal

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Event-Driven Persona System Tests${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Run each test suite with better error handling
run_test_suite() {
  local test_file="$1"
  local timeout="${2:-120}"  # Default 2 minute timeout per suite
  
  echo -e "${YELLOW}Running $(basename "$test_file")...${NC}"
  
  # Clean up between test suites
  kill_existing_processes
  
  # Check if test file exists and is executable
  if [ ! -f "$test_file" ]; then
    echo -e "${RED}✗ Test file not found: $test_file${NC}"
    return 1
  fi
  
  # Run test suite with timeout and better error handling
  local output_file="/tmp/test-output-$$.log"
  
  # Use bash explicitly to avoid any shell interpretation issues
  if timeout --preserve-status --signal=TERM --kill-after=10 $timeout bash "$test_file" > "$output_file" 2>&1; then
    cat "$output_file"
    rm -f "$output_file"
    echo -e "${GREEN}✓ $(basename "$test_file") passed${NC}"
    return 0
  else
    local exit_code=$?
    cat "$output_file"
    rm -f "$output_file"
    
    if [ $exit_code -eq 124 ]; then
      echo -e "${RED}✗ $(basename "$test_file") timed out${NC}"
    else
      echo -e "${RED}✗ $(basename "$test_file") failed with exit code $exit_code${NC}"
    fi
    
    # For debugging failing tests, show more info
    if [[ "$(basename "$test_file")" =~ ^test-(merger|qa|reviewer)-actor\.sh$ ]]; then
      echo -e "${YELLOW}Debug: Checking why $(basename "$test_file") is failing...${NC}"
      
      # Check if the actor script exists
      local actor_name=$(basename "$test_file" .sh | sed 's/test-//' | sed 's/-actor//')
      local actor_script="/usr/local/bin/${actor_name}-actor.sh"
      
      if [ -f "$actor_script" ]; then
        echo "  - Actor script exists: $actor_script"
        
        # Check if it sources problematic files
        if grep -q "source es-actor-base.sh" "$actor_script"; then
          echo "  - Actor sources es-actor-base.sh (potential blocking)"
        fi
        
        # Check for syntax errors
        if ! bash -n "$actor_script" 2>/dev/null; then
          echo "  - Actor script has syntax errors"
        fi
      else
        echo "  - Actor script not found: $actor_script"
      fi
    fi
    
    return 1
  fi
}

# Run each test suite
for test_file in "$TEST_DIR"/test-*.sh; do
  # Skip the framework file and this file
  if [ -f "$test_file" ] && [ "$test_file" != "$TEST_DIR/test-framework.sh" ] && [ "$(basename "$test_file")" != "run-all-tests.sh" ]; then
    ((TOTAL_SUITES++))

    if run_test_suite "$test_file"; then
      ((PASSED_SUITES++))
    else
      ((FAILED_SUITES++))
    fi

    echo ""
  fi
done

# Final cleanup
kill_existing_processes

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo "Test suites run:    $TOTAL_SUITES"
echo -e "Test suites passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Test suites failed: ${RED}$FAILED_SUITES${NC}"

if [ $FAILED_SUITES -eq 0 ]; then
  echo -e "\n${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "\n${RED}Some tests failed!${NC}"
  exit 1
fi
