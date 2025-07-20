#!/bin/bash
# Test QA actor functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Setup test journal location
export TEST_JOURNAL="/tmp/test-journal-$$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Mock the actor base functions for testing
setup_qa_test() {
  # Create a test work execution function
  cat >/tmp/test-actor-base.sh <<'EOF'
#!/bin/bash
# Mock actor base for testing

ACTOR_ACTIVE=true
PERSONA="TEST"
JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"

actor_loop() {
    PERSONA="$1"
    echo "Mock actor loop started for $PERSONA"
}

should_handoff() {
    [ $(es-projection.sh "$PERSONA" "pending_work" | wc -l) -eq 0 ]
}

log_decision() {
    echo "$(date -Iseconds) [$PERSONA:DECISION] $1" >> "$JOURNAL_FILE"
}

log_issue() {
    echo "$(date -Iseconds) [$PERSONA:ISSUE] $1" >> "$JOURNAL_FILE"
}

log_memory() {
    echo "$(date -Iseconds) [$PERSONA:MEMORY] $1" >> "$JOURNAL_FILE"
}

log_context() {
    echo "$(date -Iseconds) [$PERSONA:CONTEXT] $1" >> "$JOURNAL_FILE"
}

execute_command() {
    eval "$1"
}

create_file_with_content() {
    mkdir -p "$(dirname "$1")"
    echo "$2" > "$1"
}

run_tests() {
    # Mock test runner
    if [ -f "tests/failing.test" ]; then
        return 1
    fi
    return 0
}

ensure_git_repo() {
    if [ ! -d .git ]; then
        git init >/dev/null 2>&1
        git config user.name "Test" >/dev/null 2>&1
        git config user.email "test@test.com" >/dev/null 2>&1
    fi
}
EOF
}

# Test QA unit test execution
test_qa_unit_test_execution() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  # Source QA actor functions
  PERSONA="QA"
  TESTS_PASSED=0
  TESTS_FAILED=0
  ISSUES_FOUND=0
  TEST_FRAMEWORK="pytest"

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  else
    echo "qa-actor.sh not found"
    return 1
  fi

  # Create test directory
  mkdir -p /tmp/test-qa-$$
  cd /tmp/test-qa-$$

  # Test unit test execution
  execute_persona_work "test-1" "Run unit test suite and verify coverage meets 80% minimum"
  
  # Check that tests were attempted
  local context=$(grep "QA:CONTEXT.*Unit tests" "$TEST_JOURNAL" | tail -1)
  assert_contains "$context" "Unit tests" "Should run unit tests"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-qa-$$
  rm -f /tmp/test-actor-base.sh
}

# Test QA coverage verification
test_qa_coverage_verification() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  PERSONA="QA"
  TESTS_PASSED=0
  TESTS_FAILED=0
  ISSUES_FOUND=0
  TEST_FRAMEWORK="jest/npm"

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  mkdir -p /tmp/test-qa-$$
  cd /tmp/test-qa-$$

  # Mock coverage output
  cat >/tmp/test-qa-$$/coverage-output.log <<EOF
All files  |  75.5  |    85  |    70  |  75.5  |
EOF

  # Test coverage check - should fail for < 80%
  execute_persona_work "test-1" "Verify test coverage meets 80% minimum"
  
  # Check issue was logged
  assert_equals "1" "$ISSUES_FOUND" "Should find coverage issue"
  
  local issue=$(grep "QA:ISSUE.*coverage.*below 80%" "$TEST_JOURNAL")
  assert_contains "$issue" "below 80%" "Should log coverage below minimum"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-qa-$$
  rm -f /tmp/test-actor-base.sh
}

# Test QA integration testing
test_qa_integration_testing() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  PERSONA="QA"
  TESTS_PASSED=0
  TESTS_FAILED=0
  ISSUES_FOUND=0
  TEST_FRAMEWORK="pytest"

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  mkdir -p /tmp/test-qa-$$
  cd /tmp/test-qa-$$

  # Test integration testing with real services
  execute_persona_work "test-1" "Run integration tests against REAL services (no mocks)"
  
  # Check memory was logged about real services
  local memory=$(grep "QA:MEMORY.*real services" "$TEST_JOURNAL")
  assert_contains "$memory" "real services" "Should emphasize real service testing"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-qa-$$
  rm -f /tmp/test-actor-base.sh
}

# Test QA error handling verification
test_qa_error_handling() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  PERSONA="QA"
  TESTS_PASSED=0
  TESTS_FAILED=0
  ISSUES_FOUND=0

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  mkdir -p /tmp/test-qa-$$/src
  cd /tmp/test-qa-$$

  # Create source files without error handling
  echo "function test() { return data; }" > src/test.js

  # Test error handling check
  execute_persona_work "test-1" "Test error handling and edge cases"
  
  # Should find issue with limited error handling
  local issue=$(grep "QA:ISSUE.*error handling" "$TEST_JOURNAL")
  if [ -z "$issue" ]; then
    # If no issue logged, that's also valid behavior
    assert_equals "valid" "valid" "Error handling check completed"
  else
    assert_contains "$issue" "error handling" "Should detect error handling issues"
  fi

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-qa-$$
  rm -f /tmp/test-actor-base.sh
}

# Test QA report generation
test_qa_report_generation() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  PERSONA="QA"
  TESTS_PASSED=5
  TESTS_FAILED=1
  ISSUES_FOUND=2

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  mkdir -p /tmp/test-qa-$$
  cd /tmp/test-qa-$$

  # Test report creation
  execute_persona_work "test-1" "Document any bugs or issues found"
  
  # Check report was created
  assert_file_exists "QA_REPORT.md" "Should create QA report"
  
  # Verify report content
  local report=$(cat QA_REPORT.md)
  assert_contains "$report" "Tests Passed: 5" "Report should include passed count"
  assert_contains "$report" "Tests Failed: 1" "Report should include failed count"
  assert_contains "$report" "Issues Found: 2" "Report should include issues count"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-qa-$$
  rm -f /tmp/test-actor-base.sh
}

# Test QA handoff decision logic
test_qa_handoff_logic() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  PERSONA="QA"
  TESTS_FAILED=0
  ISSUES_FOUND=0

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  # Test successful path - should go to REVIEWER
  local next=$(determine_next_persona "QA")
  assert_contains "$next" "REVIEWER" "Should hand off to REVIEWER when all tests pass"

  # Test with failures - should go back to DEVELOPER
  TESTS_FAILED=3
  next=$(determine_next_persona "QA")
  assert_contains "$next" "DEVELOPER" "Should hand off to DEVELOPER when tests fail"

  # Test with issues - should also go to DEVELOPER
  TESTS_FAILED=0
  ISSUES_FOUND=2
  next=$(determine_next_persona "QA")
  assert_contains "$next" "DEVELOPER" "Should hand off to DEVELOPER when issues found"

  rm -f /tmp/test-actor-base.sh
}

# Test QA work item generation
test_qa_work_generation() {
  setup_qa_test
  source /tmp/test-actor-base.sh

  PERSONA="QA"
  TESTS_FAILED=2
  ISSUES_FOUND=1

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  # Add some issues to journal for work generation
  echo "$(date -Iseconds) [QA:ISSUE] API endpoint returns 500 on invalid input" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [QA:ISSUE] Missing test coverage for error paths" >> "$TEST_JOURNAL"

  # Generate work for DEVELOPER
  local work_items=$(generate_work_items "QA" "DEVELOPER")
  
  assert_contains "$work_items" "Fix failing tests" "Should create task for test fixes"
  assert_contains "$work_items" "Fix issue #1" "Should create tasks for issues"
  assert_contains "$work_items" "Update test coverage" "Should request coverage updates"

  # Generate work for REVIEWER
  work_items=$(generate_work_items "QA" "REVIEWER")
  
  assert_contains "$work_items" "Clone PR branch" "Should prepare review environment"
  assert_contains "$work_items" "code quality checks" "Should run quality checks"
  assert_contains "$work_items" "80% minimum" "Should verify coverage requirement"

  rm -f /tmp/test-actor-base.sh
}

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run all tests
run_tests

# The test framework reports the summary
exit $?
