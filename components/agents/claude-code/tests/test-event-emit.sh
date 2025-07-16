#!/bin/bash
# Test event emission functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Test basic event emission
test_event_format() {
    setup_test
    
    # Test successful emission
    es-event-emit "WORK_ASSIGNED" "TO:DEVELOPER|ID:123|WORK:Test task"
    
    # Check event was written
    assert_event_exists "WORK_ASSIGNED" "Work assigned event should be emitted"
    
    # Check event format
    local event=$(grep "TYPE:WORK_ASSIGNED" "$TEST_JOURNAL" | tail -1)
    assert_contains "$event" "TO:DEVELOPER" "Event should contain TO field"
    assert_contains "$event" "ID:123" "Event should contain ID field"
    assert_contains "$event" "WORK:Test task" "Event should contain WORK field"
    
    teardown_test
}

# Test required field validation
test_required_fields() {
    setup_test
    
    # Test missing TO field
    local output=$(es-event-emit "WORK_ASSIGNED" "ID:123|WORK:Test" 2>&1)
    local exit_code=$?
    assert_exit_code 1 $exit_code "Should fail with missing TO field"
    assert_contains "$output" "Missing required field: TO" "Should report missing TO field"
    
    # Test missing ID field
    output=$(es-event-emit "WORK_ASSIGNED" "TO:DEVELOPER|WORK:Test" 2>&1)
    exit_code=$?
    assert_exit_code 1 $exit_code "Should fail with missing ID field"
    assert_contains "$output" "Missing required field: ID" "Should report missing ID field"
    
    # Test missing WORK field
    output=$(es-event-emit "WORK_ASSIGNED" "TO:DEVELOPER|ID:123" 2>&1)
    exit_code=$?
    assert_exit_code 1 $exit_code "Should fail with missing WORK field"
    assert_contains "$output" "Missing required field: WORK" "Should report missing WORK field"
    
    teardown_test
}

# Test different event types
test_event_types() {
    setup_test
    
    # Test WORK_STARTED event
    es-event-emit "WORK_STARTED" "PERSONA:DEVELOPER|WORK_ID:123"
    assert_event_exists "WORK_STARTED" "Work started event should be emitted"
    
    # Test WORK_COMPLETED event
    es-event-emit "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:123"
    assert_event_exists "WORK_COMPLETED" "Work completed event should be emitted"
    
    # Test PERSONA_ACTIVATED event
    es-event-emit "PERSONA_ACTIVATED" "PERSONA:QA|PID:9999"
    assert_event_exists "PERSONA_ACTIVATED" "Persona activated event should be emitted"
    
    # Test HANDOFF_READY event
    es-event-emit "HANDOFF_READY" "FROM:DEVELOPER|TO:QA"
    assert_event_exists "HANDOFF_READY" "Handoff ready event should be emitted"
    
    teardown_test
}

# Test human-readable logging
test_human_readable_entries() {
    setup_test
    
    # Test work assignment creates readable entry
    es-event-emit "WORK_ASSIGNED" "TO:DEVELOPER|ID:123|WORK:Create user authentication"
    
    # Check for human-readable entry
    local journal_content=$(cat "$TEST_JOURNAL")
    assert_contains "$journal_content" "[DEVELOPER:ASSIGNED] Create user authentication" \
        "Should create human-readable work assignment entry"
    
    # Test work completion creates readable entry
    es-event-emit "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:123"
    journal_content=$(cat "$TEST_JOURNAL")
    assert_contains "$journal_content" "[DEVELOPER:COMPLETED] Work item 123" \
        "Should create human-readable completion entry"
    
    teardown_test
}

# Test timestamp format
test_timestamp_format() {
    setup_test
    
    es-event-emit "TEST_EVENT" "FIELD:value"
    
    local event_line=$(grep "TYPE:TEST_EVENT" "$TEST_JOURNAL")
    # Check ISO 8601 timestamp format (YYYY-MM-DDTHH:MM:SS)
    assert_contains "$event_line" "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}" \
        "Event should have ISO 8601 timestamp"
    
    teardown_test
}

# Test decision and memory events
test_logging_events() {
    setup_test
    
    # These events don't require specific fields
    es-event-emit "DECISION" "PERSONA:ARCHITECT|CONTENT:Chose microservices architecture"
    assert_event_exists "DECISION" "Decision event should be emitted"
    
    es-event-emit "MEMORY" "PERSONA:DEVELOPER|CONTENT:API uses JWT tokens"
    assert_event_exists "MEMORY" "Memory event should be emitted"
    
    es-event-emit "ISSUE" "PERSONA:QA|CONTENT:Test coverage below 80%"
    assert_event_exists "ISSUE" "Issue event should be emitted"
    
    teardown_test
}

# Run all tests
run_tests
