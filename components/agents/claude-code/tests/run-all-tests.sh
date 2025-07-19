#!/bin/bash
# Run all tests for the event-driven persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Change to tests directory
cd "$(dirname "$0")"

# Ensure scripts are in PATH
export PATH="../scripts/event-sourcing:../scripts/personas:../scripts/common:$PATH"

# Kill any existing processes from previous test runs
kill_existing_processes() {
  echo "Cleaning up any existing processes..."
  
  # Kill any existing event monitors
  pkill -f es-event-monitor 2>/dev/null || true
  
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

# Run each test suite
for test_file in test-*.sh; do
  if [ -f "$test_file" ] && [ "$test_file" != "test-framework.sh" ]; then
    ((TOTAL_SUITES++))

    echo -e "${YELLOW}Running $test_file...${NC}"

    # Clean up between test suites
    kill_existing_processes

    # Run test in a subshell to isolate variables
    if (bash "$test_file"); then
      ((PASSED_SUITES++))
      echo -e "${GREEN}✓ $test_file passed${NC}"
    else
      ((FAILED_SUITES++))
      echo -e "${RED}✗ $test_file failed${NC}"
    fi

    echo ""
  fi
done

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
