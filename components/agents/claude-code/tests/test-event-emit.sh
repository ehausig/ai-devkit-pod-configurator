#!/bin/bash
# Test event emission functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Kill any processes that might interfere
pkill -f es-event-monitor.sh 2>/dev/null || true
pkill -f "actor" 2>/dev/null || true
rm -f /tmp/es-event-monitor.pid
rm -f /tmp/es-event-monitor.lastline
sleep 0.5

# Test basic event emission
test_event_format() {
  # Test successful emission
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:123|WORK:Test task"

  # Check event was written
  assert_event_exists "WORK_ASSIGNED" "Work assigned event should be emitted"

  # Check event format
  local event=$(grep "TYPE:WORK_ASSIGNED" "$TEST_JOURNAL" | tail -1)
  assert_contains "$event" "TO:DEVELOPER" "Event should contain TO field"
  assert_contains "$event" "ID:123" "Event should contain ID field"
  assert_contains "$event" "WORK:Test task" "Event should contain WORK field"
}

# Test required field validation
test_required_fields() {
  # Test missing TO field - run in current shell to get exit code
  es-event-emit.sh "WORK_ASSIGNED" "ID:123|WORK:Test" 2>&1 >/dev/null
  local exit_code=$?
  assert_exit_code 1 $exit_code "Should fail with missing TO field"

  # Check error message separately
  local output=$(es-event-emit.sh "WORK_ASSIGNED" "ID:123|WORK:Test" 2>&1)
  assert_contains "$output" "Missing required field: TO" "Should report missing TO field"

  # Test missing ID field
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|WORK:Test" 2>&1 >/dev/null
  exit_code=$?
  assert_exit_code 1 $exit_code "Should fail with missing ID field"

  output=$(es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|WORK:Test" 2>&1)
  assert_contains "$output" "Missing required field: ID" "Should report missing ID field"

  # Test missing WORK field
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:123" 2>&1 >/dev/null
  exit_code=$?
  assert_exit_code 1 $exit_code "Should fail with missing WORK field"

  output=$(es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:123" 2>&1)
  assert_contains "$output" "Missing required field: WORK" "Should report missing WORK field"
}

# Test different event types
test_event_types() {
  # Test WORK_STARTED event
  es-event-emit.sh "WORK_STARTED" "PERSONA:DEVELOPER|WORK_ID:123"
  assert_event_exists "WORK_STARTED" "Work started event should be emitted"

  # Test WORK_COMPLETED event
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:123"
  assert_event_exists "WORK_COMPLETED" "Work completed event should be emitted"

  # Test PERSONA_ACTIVATED event
  es-event-emit.sh "PERSONA_ACTIVATED" "PERSONA:QA|PID:9999"
  assert_event_exists "PERSONA_ACTIVATED" "Persona activated event should be emitted"

  # Test HANDOFF_READY event
  es-event-emit.sh "HANDOFF_READY" "FROM:DEVELOPER|TO:QA"
  assert_event_exists "HANDOFF_READY" "Handoff ready event should be emitted"
}

# Test human-readable logging
test_human_readable_entries() {
  # Test work assignment creates readable entry
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:123|WORK:Create user authentication"

  # Check for human-readable entry - use grep directly
  if grep -q "\[DEVELOPER:ASSIGNED\] Create user authentication" "$TEST_JOURNAL"; then
    assert_equals "found" "found" "Should create human-readable work assignment entry"
  else
    # Debug output
    echo "Debug: Journal contents:"
    cat "$TEST_JOURNAL"
    assert_equals "found" "not_found" "Should create human-readable work assignment entry"
  fi

  # Test work completion creates readable entry
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:123"

  if grep -q "\[DEVELOPER:COMPLETED\] Work item 123" "$TEST_JOURNAL"; then
    assert_equals "found" "found" "Should create human-readable completion entry"
  else
    assert_equals "found" "not_found" "Should create human-readable completion entry"
  fi
}

# Test timestamp format
test_timestamp_format() {
  es-event-emit.sh "TEST_EVENT" "FIELD:value"

  local event_line=$(grep "TYPE:TEST_EVENT" "$TEST_JOURNAL")
  # Check ISO 8601 timestamp format (YYYY-MM-DDTHH:MM:SS with optional timezone)
  if echo "$event_line" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}" >/dev/null; then
    assert_equals "valid" "valid" "Event should have ISO 8601 timestamp"
  else
    assert_equals "valid" "invalid" "Event should have ISO 8601 timestamp"
  fi
}

# Test decision and memory events
test_logging_events() {
  # These events don't require specific fields
  es-event-emit.sh "DECISION" "PERSONA:ARCHITECT|CONTENT:Chose microservices architecture"
  assert_event_exists "DECISION" "Decision event should be emitted"

  es-event-emit.sh "MEMORY" "PERSONA:DEVELOPER|CONTENT:API uses JWT tokens"
  assert_event_exists "MEMORY" "Memory event should be emitted"

  es-event-emit.sh "ISSUE" "PERSONA:QA|CONTENT:Test coverage below 80%"
  assert_event_exists "ISSUE" "Issue event should be emitted"
}

# Run all tests
run_tests
