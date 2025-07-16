#!/bin/bash
# Test CQRS projection functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Test pending work filtering
test_pending_work_filtering() {
  setup_test

  # Add work assigned events
  echo "2024-01-01T10:00:00 [EVENT] TYPE:WORK_ASSIGNED|TO:DEVELOPER|ID:1|WORK:Task 1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_COMPLETED|PERSONA:DEVELOPER|WORK_ID:1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:02:00 [EVENT] TYPE:WORK_ASSIGNED|TO:DEVELOPER|ID:2|WORK:Task 2" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:03:00 [EVENT] TYPE:WORK_ASSIGNED|TO:DEVELOPER|ID:3|WORK:Task 3" >>"$TEST_JOURNAL"

  # Get pending work
  local pending=$(es-projection "DEVELOPER" "pending_work")

  # Should not include completed work
  assert_not_contains "$pending" "ID:1" "Completed work should not be in pending"
  assert_contains "$pending" "ID:2" "Uncompleted work 2 should be pending"
  assert_contains "$pending" "ID:3" "Uncompleted work 3 should be pending"

  # Test count
  local count=$(echo "$pending" | grep -c "TYPE:WORK_ASSIGNED")
  assert_equals 2 $count "Should have 2 pending work items"

  teardown_test
}

# Test current state detection
test_current_state() {
  setup_test

  # Test UNKNOWN state (no events)
  local state=$(es-projection "ARCHITECT" "current_state")
  assert_equals "UNKNOWN" "$state" "Should be UNKNOWN with no events"

  # Test ACTIVE state
  echo "2024-01-01T10:00:00 [EVENT] TYPE:PERSONA_ACTIVATED|PERSONA:ARCHITECT|PID:1234" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_ASSIGNED|TO:ARCHITECT|ID:1|WORK:Design system" >>"$TEST_JOURNAL"

  state=$(es-projection "ARCHITECT" "current_state")
  assert_equals "ACTIVE" "$state" "Should be ACTIVE after activation with pending work"

  # Test IDLE state
  echo "2024-01-01T10:02:00 [EVENT] TYPE:WORK_COMPLETED|PERSONA:ARCHITECT|WORK_ID:1" >>"$TEST_JOURNAL"
  state=$(es-projection "ARCHITECT" "current_state")
  assert_equals "IDLE" "$state" "Should be IDLE when no pending work"

  # Test COMPLETE state
  echo "2024-01-01T10:03:00 [EVENT] TYPE:HANDOFF_READY|FROM:ARCHITECT|TO:DEVELOPER" >>"$TEST_JOURNAL"
  state=$(es-projection "ARCHITECT" "current_state")
  assert_equals "COMPLETE" "$state" "Should be COMPLETE after handoff"

  teardown_test
}

# Test work history - FIXED
test_work_history() {
  setup_test

  # Add work events
  echo "2024-01-01T10:00:00 [EVENT] TYPE:WORK_ASSIGNED|TO:DEVELOPER|ID:1|WORK:Implement feature" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_STARTED|PERSONA:DEVELOPER|WORK_ID:1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:02:00 [EVENT] TYPE:WORK_COMPLETED|PERSONA:DEVELOPER|WORK_ID:1" >>"$TEST_JOURNAL"

  # Test specific work item history
  local history=$(es-projection "DEVELOPER" "work_history" "1")
  assert_contains "$history" "WORK_ASSIGNED" "Should show work assignment"
  assert_contains "$history" "WORK_STARTED" "Should show work started"
  assert_contains "$history" "WORK_COMPLETED" "Should show work completed"

  # Test all work history for persona - count non-empty lines
  history=$(es-projection "DEVELOPER" "work_history")
  local count=$(echo "$history" | grep -E "TYPE:WORK_|WORK_ID:" | wc -l)
  assert_equals 3 $count "Should have 3 history entries"

  teardown_test
}

# Test next work selection
test_next_work() {
  setup_test

  # Add multiple work items
  echo "2024-01-01T10:00:00 [EVENT] TYPE:WORK_ASSIGNED|TO:QA|ID:1|WORK:First task" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_ASSIGNED|TO:QA|ID:2|WORK:Second task" >>"$TEST_JOURNAL"

  # Should get oldest first
  local next=$(es-projection "QA" "next_work")
  assert_contains "$next" "ID:1" "Should return oldest work item first"
  assert_contains "$next" "First task" "Should contain work description"

  teardown_test
}

# Test work description extraction
test_work_description() {
  setup_test

  # Add work with description
  echo "2024-01-01T10:00:00 [EVENT] TYPE:WORK_ASSIGNED|TO:REVIEWER|ID:abc123|WORK:Review code for security issues" >>"$TEST_JOURNAL"

  # Extract description
  local desc=$(es-projection "REVIEWER" "work_description" "abc123")
  assert_equals "Review code for security issues" "$desc" "Should extract work description"

  teardown_test
}

# Test statistics
test_stats() {
  setup_test

  # Add various events
  echo "2024-01-01T10:00:00 [EVENT] TYPE:WORK_ASSIGNED|TO:MERGER|ID:1|WORK:Task 1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_ASSIGNED|TO:MERGER|ID:2|WORK:Task 2" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:02:00 [EVENT] TYPE:WORK_COMPLETED|PERSONA:MERGER|WORK_ID:1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:03:00 [EVENT] TYPE:WORK_FAILED|PERSONA:MERGER|WORK_ID:2" >>"$TEST_JOURNAL"

  # Get stats
  local stats=$(es-projection "MERGER" "stats")

  assert_contains "$stats" "Total Assigned: 2" "Should show total assigned"
  assert_contains "$stats" "Completed: 1" "Should show completed count"
  assert_contains "$stats" "Failed: 1" "Should show failed count"
  assert_contains "$stats" "Pending: 0" "Should show pending count"

  teardown_test
}

# Test handoff detection
test_last_handoff_to() {
  setup_test

  # Add handoff events
  echo "2024-01-01T10:00:00 [EVENT] TYPE:HANDOFF_READY|FROM:ARCHITECT|TO:DEVELOPER" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:HANDOFF_READY|FROM:DEVELOPER|TO:QA" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:02:00 [EVENT] TYPE:HANDOFF_READY|FROM:REVIEWER|TO:DEVELOPER" >>"$TEST_JOURNAL"

  # Check last handoff to DEVELOPER
  local from=$(es-projection "DEVELOPER" "last_handoff_to")
  assert_equals "REVIEWER" "$from" "Should show REVIEWER handed off to DEVELOPER"

  teardown_test
}

# Test system state overview
test_system_state() {
  setup_test

  # Set up various persona states
  echo "2024-01-01T10:00:00 [EVENT] TYPE:PERSONA_ACTIVATED|PERSONA:ARCHITECT|PID:1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_ASSIGNED|TO:ARCHITECT|ID:1|WORK:Task" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:02:00 [EVENT] TYPE:PERSONA_ACTIVATED|PERSONA:DEVELOPER|PID:2" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:03:00 [EVENT] TYPE:HANDOFF_READY|FROM:DEVELOPER|TO:QA" >>"$TEST_JOURNAL"

  # Get system state
  local state=$(es-projection "" "system_state")

  assert_contains "$state" "ARCHITECT: ACTIVE" "Should show ARCHITECT as ACTIVE"
  assert_contains "$state" "DEVELOPER: COMPLETE" "Should show DEVELOPER as COMPLETE"
  assert_contains "$state" "QA: UNKNOWN" "Should show QA as UNKNOWN"

  teardown_test
}

# Test active personas list
test_active_personas() {
  setup_test

  # Activate multiple personas
  echo "2024-01-01T10:00:00 [EVENT] TYPE:PERSONA_ACTIVATED|PERSONA:ARCHITECT|PID:1" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:01:00 [EVENT] TYPE:WORK_ASSIGNED|TO:ARCHITECT|ID:1|WORK:Task" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:02:00 [EVENT] TYPE:PERSONA_ACTIVATED|PERSONA:QA|PID:2" >>"$TEST_JOURNAL"
  echo "2024-01-01T10:03:00 [EVENT] TYPE:WORK_ASSIGNED|TO:QA|ID:2|WORK:Test" >>"$TEST_JOURNAL"

  # Get active personas
  local active=$(es-projection "" "active_personas")

  assert_contains "$active" "ARCHITECT" "Should list ARCHITECT as active"
  assert_contains "$active" "QA" "Should list QA as active"
  assert_not_contains "$active" "DEVELOPER" "Should not list DEVELOPER as active"

  teardown_test
}

# Run all tests
run_tests
