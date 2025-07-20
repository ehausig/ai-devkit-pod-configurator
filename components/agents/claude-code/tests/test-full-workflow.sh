#!/bin/bash
# Test full workflow from ARCHITECT through MERGER

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Setup test journal location
export TEST_JOURNAL="/tmp/test-journal-$$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Test complete happy path workflow
test_complete_happy_path() {
  # Initialize journal
  echo "# Test Workflow Journal" > "$TEST_JOURNAL"
  echo "" >> "$TEST_JOURNAL"

  # Simulate initial work assignment to ARCHITECT
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:arch-1|WORK:Create system architecture based on requirements"
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:arch-2|WORK:Design API specification"
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:arch-3|WORK:Define data models and schemas"
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:arch-4|WORK:Create testing strategy"

  # Simulate ARCHITECT completing work
  es-event-emit.sh "WORK_STARTED" "PERSONA:ARCHITECT|WORK_ID:arch-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:arch-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:arch-2"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:arch-3"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:arch-4"

  # ARCHITECT hands off to DEVELOPER
  es-event-emit.sh "HANDOFF_INITIATED" "FROM:ARCHITECT|REASON:All design documents complete"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-1|WORK:Create feature branch feat/initial-implementation"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-2|WORK:Initialize project with python tooling"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-3|WORK:Write failing tests for core data models"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-4|WORK:Implement data models to pass tests"
  es-event-emit.sh "HANDOFF_READY" "FROM:ARCHITECT|TO:DEVELOPER|COUNT:4"

  # Verify ARCHITECT completed all work
  local arch_pending=$(es-projection.sh "ARCHITECT" "pending_work" | wc -l)
  assert_equals "0" "$arch_pending" "ARCHITECT should have no pending work"

  # Verify DEVELOPER has work
  local dev_pending=$(es-projection.sh "DEVELOPER" "pending_work" | wc -l)
  assert_equals "4" "$dev_pending" "DEVELOPER should have 4 pending items"

  # Simulate DEVELOPER completing work
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-2"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-3"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-4"

  # DEVELOPER hands off to QA
  es-event-emit.sh "HANDOFF_INITIATED" "FROM:DEVELOPER|REASON:All tests passing and PR created"
  es-event-emit.sh "WORK_ASSIGNED" "TO:QA|ID:qa-1|WORK:Run unit test suite and verify coverage meets 80% minimum"
  es-event-emit.sh "WORK_ASSIGNED" "TO:QA|ID:qa-2|WORK:Run integration tests against REAL services (no mocks)"
  es-event-emit.sh "HANDOFF_READY" "FROM:DEVELOPER|TO:QA|COUNT:2"

  # QA completes testing
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:QA|WORK_ID:qa-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:QA|WORK_ID:qa-2"

  # QA hands off to REVIEWER
  es-event-emit.sh "HANDOFF_INITIATED" "FROM:QA|REASON:All tests passed, ready for code review"
  es-event-emit.sh "WORK_ASSIGNED" "TO:REVIEWER|ID:rev-1|WORK:Review code against architectural decisions"
  es-event-emit.sh "WORK_ASSIGNED" "TO:REVIEWER|ID:rev-2|WORK:Check for security vulnerabilities"
  es-event-emit.sh "HANDOFF_READY" "FROM:QA|TO:REVIEWER|COUNT:2"

  # REVIEWER approves
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:REVIEWER|WORK_ID:rev-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:REVIEWER|WORK_ID:rev-2"

  # REVIEWER hands off to MERGER
  es-event-emit.sh "HANDOFF_INITIATED" "FROM:REVIEWER|REASON:Code approved, ready for merge"
  es-event-emit.sh "WORK_ASSIGNED" "TO:MERGER|ID:merge-1|WORK:Merge PR using --no-ff for clear history"
  es-event-emit.sh "WORK_ASSIGNED" "TO:MERGER|ID:merge-2|WORK:Update CHANGELOG.md with version and changes"
  es-event-emit.sh "HANDOFF_READY" "FROM:REVIEWER|TO:MERGER|COUNT:2"

  # MERGER completes
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:MERGER|WORK_ID:merge-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:MERGER|WORK_ID:merge-2"
  es-event-emit.sh "CYCLE_COMPLETE" "FINAL_PERSONA:MERGER"

  # Verify complete workflow
  local all_pending=0
  for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    local pending=$(es-projection.sh "$persona" "pending_work" | wc -l)
    ((all_pending += pending))
  done
  assert_equals "0" "$all_pending" "All personas should have completed work"

  # Check cycle completion
  local cycle_complete=$(grep "CYCLE_COMPLETE" "$TEST_JOURNAL")
  assert_contains "$cycle_complete" "MERGER" "Cycle should complete with MERGER"
}

# Test workflow with review rejection
test_workflow_with_rejection() {
  # Similar setup but REVIEWER finds issues
  es-event-emit.sh "WORK_ASSIGNED" "TO:REVIEWER|ID:rev-1|WORK:Review code quality"
  es-event-emit.sh "WORK_STARTED" "PERSONA:REVIEWER|WORK_ID:rev-1"
  
  # REVIEWER logs issues
  echo "$(date -Iseconds) [REVIEWER:ISSUE] SQL injection vulnerability found" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [REVIEWER:ISSUE] Missing input validation" >> "$TEST_JOURNAL"
  
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:REVIEWER|WORK_ID:rev-1"

  # REVIEWER hands back to DEVELOPER
  es-event-emit.sh "HANDOFF_INITIATED" "FROM:REVIEWER|REASON:Found 2 critical issues requiring fixes"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-fix-1|WORK:Fix issue #1: SQL injection vulnerability found"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-fix-2|WORK:Fix issue #2: Missing input validation"
  es-event-emit.sh "HANDOFF_READY" "FROM:REVIEWER|TO:DEVELOPER|COUNT:2"

  # Verify DEVELOPER got fix work
  local dev_work=$(es-projection.sh "DEVELOPER" "pending_work")
  assert_contains "$dev_work" "SQL injection" "DEVELOPER should get security fix task"
  assert_contains "$dev_work" "input validation" "DEVELOPER should get validation fix task"

  # DEVELOPER fixes issues
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-fix-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-fix-2"

  # Back to QA for re-testing
  es-event-emit.sh "HANDOFF_INITIATED" "FROM:DEVELOPER|REASON:Review issues fixed"
  es-event-emit.sh "WORK_ASSIGNED" "TO:QA|ID:qa-retest-1|WORK:Re-test security fixes"
  es-event-emit.sh "HANDOFF_READY" "FROM:DEVELOPER|TO:QA|COUNT:1"

  # Verify non-linear flow
  local handoffs=$(grep "HANDOFF_READY" "$TEST_JOURNAL" | wc -l)
  assert_equals "3" "$handoffs" "Should have multiple handoffs in rejection flow"
}

# Test concurrent persona work
test_concurrent_personas() {
  # Multiple personas can have work at the same time
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:arch-1|WORK:Design new feature"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-1|WORK:Fix bug in existing code"
  es-event-emit.sh "WORK_ASSIGNED" "TO:QA|ID:qa-1|WORK:Test hotfix"

  # Verify all have work
  local arch_pending=$(es-projection.sh "ARCHITECT" "pending_work" | wc -l)
  local dev_pending=$(es-projection.sh "DEVELOPER" "pending_work" | wc -l)
  local qa_pending=$(es-projection.sh "QA" "pending_work" | wc -l)

  assert_equals "1" "$arch_pending" "ARCHITECT should have work"
  assert_equals "1" "$dev_pending" "DEVELOPER should have work"
  assert_equals "1" "$qa_pending" "QA should have work"

  # Simulate concurrent completion
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:QA|WORK_ID:qa-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:arch-1"

  # All should be idle
  local arch_state=$(es-projection.sh "ARCHITECT" "current_state")
  local dev_state=$(es-projection.sh "DEVELOPER" "current_state")
  local qa_state=$(es-projection.sh "QA" "current_state")

  assert_equals "IDLE" "$arch_state" "ARCHITECT should be idle"
  assert_equals "IDLE" "$dev_state" "DEVELOPER should be idle"
  assert_equals "IDLE" "$qa_state" "QA should be idle"
}

# Test work failure and recovery
test_work_failure_recovery() {
  # Assign work to DEVELOPER
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-1|WORK:Implement complex feature"
  es-event-emit.sh "WORK_STARTED" "PERSONA:DEVELOPER|WORK_ID:dev-1"

  # Work fails
  es-event-emit.sh "WORK_FAILED" "PERSONA:DEVELOPER|WORK_ID:dev-1|REASON:Dependencies not available"

  # Log issue and retry strategy
  echo "$(date -Iseconds) [DEVELOPER:ISSUE] Dependencies not available for feature" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Installing missing dependencies" >> "$TEST_JOURNAL"

  # Retry work
  es-event-emit.sh "WORK_STARTED" "PERSONA:DEVELOPER|WORK_ID:dev-1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-1"

  # Verify work history shows failure and recovery
  local history=$(es-projection.sh "DEVELOPER" "work_history" "dev-1")
  assert_contains "$history" "WORK_FAILED" "History should show failure"
  assert_contains "$history" "WORK_COMPLETED" "History should show eventual success"
}

# Test multiple project cycles
test_multiple_cycles() {
  # First cycle
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:cycle1-1|WORK:Design feature A"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:cycle1-1"
  es-event-emit.sh "CYCLE_COMPLETE" "FINAL_PERSONA:MERGER"

  # Second cycle starts
  es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:cycle2-1|WORK:Design feature B"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:ARCHITECT|WORK_ID:cycle2-1"

  # Check that cycles are tracked
  local cycles=$(grep -c "CYCLE_COMPLETE" "$TEST_JOURNAL")
  assert_equals "1" "$cycles" "Should have one completed cycle"

  # Complete second cycle
  es-event-emit.sh "CYCLE_COMPLETE" "FINAL_PERSONA:MERGER"
  cycles=$(grep -c "CYCLE_COMPLETE" "$TEST_JOURNAL")
  assert_equals "2" "$cycles" "Should have two completed cycles"
}

# Test decision and memory persistence
test_decision_memory_tracking() {
  # Log various decisions throughout workflow
  echo "$(date -Iseconds) [ARCHITECT:DECISION] Chose microservices architecture for scalability" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [ARCHITECT:MEMORY] System must support 10k concurrent users" >> "$TEST_JOURNAL"
  
  echo "$(date -Iseconds) [DEVELOPER:DECISION] Using Python with FastAPI framework" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [DEVELOPER:MEMORY] API rate limit set to 100 requests/minute" >> "$TEST_JOURNAL"
  
  echo "$(date -Iseconds) [QA:MEMORY] Integration tests require PostgreSQL and Redis running" >> "$TEST_JOURNAL"
  
  echo "$(date -Iseconds) [REVIEWER:DECISION] Approved with minor suggestions for error handling" >> "$TEST_JOURNAL"
  
  echo "$(date -Iseconds) [MERGER:MEMORY] Version 1.0.0 released on 2024-01-15" >> "$TEST_JOURNAL"

  # Verify decisions are tracked
  local arch_decisions=$(es-projection.sh "ARCHITECT" "decisions" | wc -l)
  assert_equals "1" "$arch_decisions" "Should track ARCHITECT decisions"

  local dev_decisions=$(es-projection.sh "DEVELOPER" "decisions" | wc -l)
  assert_equals "1" "$dev_decisions" "Should track DEVELOPER decisions"

  # Verify memory entries exist
  local memories=$(grep -c "MEMORY]" "$TEST_JOURNAL")
  assert_equals "4" "$memories" "Should track memory entries"
}

# Test handoff chain validation
test_handoff_chain() {
  # Track handoff sequence
  es-event-emit.sh "HANDOFF_READY" "FROM:ARCHITECT|TO:DEVELOPER|COUNT:5"
  es-event-emit.sh "HANDOFF_READY" "FROM:DEVELOPER|TO:QA|COUNT:3"
  es-event-emit.sh "HANDOFF_READY" "FROM:QA|TO:REVIEWER|COUNT:1"
  es-event-emit.sh "HANDOFF_READY" "FROM:REVIEWER|TO:DEVELOPER|COUNT:2"  # Back for fixes
  es-event-emit.sh "HANDOFF_READY" "FROM:DEVELOPER|TO:QA|COUNT:1"       # Re-test
  es-event-emit.sh "HANDOFF_READY" "FROM:QA|TO:REVIEWER|COUNT:1"        # Re-review
  es-event-emit.sh "HANDOFF_READY" "FROM:REVIEWER|TO:MERGER|COUNT:2"

  # Verify handoff history
  local dev_handoffs=$(es-projection.sh "DEVELOPER" "handoffs" | wc -l)
  assert_equals "3" "$dev_handoffs" "DEVELOPER involved in 3 handoffs"

  local qa_handoffs=$(es-projection.sh "QA" "handoffs" | wc -l)
  assert_equals "4" "$qa_handoffs" "QA involved in 4 handoffs"

  # Verify last handoff
  local last_to_merger=$(es-projection.sh "MERGER" "last_handoff_to")
  assert_equals "REVIEWER" "$last_to_merger" "REVIEWER should hand off to MERGER"
}

# Test system statistics
test_workflow_statistics() {
  # Create a complete workflow with various outcomes
  for i in {1..10}; do
    es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:dev-$i|WORK:Task $i"
  done

  # Complete 7, fail 2, leave 1 pending
  for i in {1..7}; do
    es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:dev-$i"
  done
  
  es-event-emit.sh "WORK_FAILED" "PERSONA:DEVELOPER|WORK_ID:dev-8|REASON:Test failure"
  es-event-emit.sh "WORK_FAILED" "PERSONA:DEVELOPER|WORK_ID:dev-9|REASON:Build error"

  # Check statistics
  local stats=$(es-projection.sh "DEVELOPER" "stats")
  assert_contains "$stats" "Total Assigned: 10" "Should show 10 assigned"
  assert_contains "$stats" "Completed: 7" "Should show 7 completed"
  assert_contains "$stats" "Failed: 2" "Should show 2 failed"
  assert_contains "$stats" "Pending: 1" "Should show 1 pending"
  assert_contains "$stats" "Success Rate: 77%" "Should calculate success rate"
}

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run all tests
run_tests

# The test framework reports the summary
exit $?
