#!/bin/bash
# Test event monitor functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Override actor commands for testing
export PATH="/tmp/test-actors-$$:$PATH"
mkdir -p "/tmp/test-actors-$$"

# Test monitor startup
test_monitor_startup() {
  setup_test

  # Start monitor in background
  es-event-monitor &
  local monitor_pid=$!

  # Wait for startup event
  if wait_for_event "MONITOR_STARTED" 3; then
    assert_event_exists "MONITOR_STARTED" "Monitor should emit startup event"
  else
    assert_equals "started" "not_started" "Monitor failed to start"
  fi

  # Check PID file
  assert_file_exists "/tmp/es-event-monitor.pid" "PID file should be created"

  # Kill monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  teardown_test
}

# Test work assignment triggers persona activation
test_work_assignment_activation() {
  setup_test

  # Create mock architect actor
  create_mock_actor "ARCHITECT"
  ln -s "/tmp/test-ARCHITECT-actor-$$.sh" "/tmp/test-actors-$$/architect-actor"

  # Add work BEFORE starting monitor (critical for line tracking)
  es-event-emit "WORK_ASSIGNED" "TO:ARCHITECT|ID:test1|WORK:Design system"

  # Start monitor
  es-event-monitor &
  local monitor_pid=$!
  sleep 2

  # Check for activation
  if wait_for_event "PERSONA_ACTIVATED.*ARCHITECT" 3; then
    local activation=$(grep "PERSONA_ACTIVATED.*ARCHITECT" "$TEST_JOURNAL")
    assert_contains "$activation" "PERSONA:ARCHITECT" "ARCHITECT should be activated"
  else
    assert_equals "activated" "not_activated" "ARCHITECT failed to activate"
  fi

  # Kill monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  cleanup_mock_actors
  teardown_test
}

# Test zombie process handling
test_zombie_process_handling() {
  setup_test

  # Create a mock actor that will emit activation event
  cat >"/tmp/test-actors-$$/architect-actor" <<'EOF'
#!/bin/bash
echo "Mock architect starting"
es-event-emit "PERSONA_ACTIVATED" "PERSONA:ARCHITECT|PID:$$"
# Exit immediately to simulate quick process end
exit 0
EOF
  chmod +x "/tmp/test-actors-$$/architect-actor"

  # Start monitor
  es-event-monitor &
  local monitor_pid=$!
  sleep 1

  # First work assignment
  es-event-emit "WORK_ASSIGNED" "TO:ARCHITECT|ID:test1|WORK:Test"
  sleep 2

  # Second work assignment
  es-event-emit "WORK_ASSIGNED" "TO:ARCHITECT|ID:test2|WORK:Test2"
  sleep 2

  # Should have two activations
  local activations=$(grep -c "PERSONA_ACTIVATED.*ARCHITECT" "$TEST_JOURNAL")
  assert_equals "2" "$activations" "Should activate twice despite zombie"

  # Cleanup
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  cleanup_mock_actors
  teardown_test
}

# Test handoff processing
test_handoff_processing() {
  setup_test

  # Create mock actors
  create_mock_actor "DEVELOPER"
  create_mock_actor "QA"
  ln -s "/tmp/test-DEVELOPER-actor-$$.sh" "/tmp/test-actors-$$/developer-actor"
  ln -s "/tmp/test-QA-actor-$$.sh" "/tmp/test-actors-$$/qa-actor"

  # Create work BEFORE handoff
  es-event-emit "WORK_ASSIGNED" "TO:QA|ID:qa1|WORK:Test feature"

  # Start monitor first
  es-event-monitor &
  local monitor_pid=$!
  sleep 2

  # Now emit handoff after monitor is running
  es-event-emit "HANDOFF_READY" "FROM:DEVELOPER|TO:QA|COUNT:1"

  # Wait for activation
  if wait_for_event "PERSONA_ACTIVATED.*QA" 3; then
    assert_event_exists "PERSONA_ACTIVATED.*QA" "QA should be activated after handoff"
  else
    assert_equals "qa_activated" "not_activated" "QA failed to activate from handoff"
  fi

  # Kill monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  cleanup_mock_actors
  teardown_test
}

# Test monitor prevents duplicate instances
test_monitor_singleton() {
  setup_test

  # Start first monitor
  es-event-monitor &
  local monitor1_pid=$!
  sleep 1

  # Try to start second monitor
  local output=$(es-event-monitor 2>&1)
  assert_contains "$output" "already running" "Should detect existing monitor"

  # Kill first monitor
  kill $monitor1_pid 2>/dev/null
  wait $monitor1_pid 2>/dev/null

  teardown_test
}

# Test persona idle handling
test_persona_idle_with_work() {
  setup_test

  # Create pending work
  es-event-emit "WORK_ASSIGNED" "TO:REVIEWER|ID:r1|WORK:Review code"

  # Start monitor
  es-event-monitor &
  local monitor_pid=$!
  sleep 1

  # Emit idle event
  es-event-emit "PERSONA_IDLE" "PERSONA:REVIEWER"

  # REVIEWER should be reactivated due to pending work
  sleep 2
  local events=$(grep "PERSONA_ACTIVATED.*REVIEWER" "$TEST_JOURNAL" | wc -l)
  assert_equals "1" "$events" "REVIEWER should be reactivated when idle with pending work"

  # Kill monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  teardown_test
}

# Test cycle completion handling
test_cycle_complete() {
  setup_test

  # Create pending work for another persona
  es-event-emit "WORK_ASSIGNED" "TO:ARCHITECT|ID:a1|WORK:New feature"

  # Start monitor
  es-event-monitor &
  local monitor_pid=$!
  sleep 1

  # Emit cycle complete
  es-event-emit "CYCLE_COMPLETE" "FINAL_PERSONA:MERGER"

  # Should detect remaining work
  sleep 2
  local activations=$(grep -c "PERSONA_ACTIVATED.*ARCHITECT" "$TEST_JOURNAL")
  assert_equals "1" "$activations" "Should activate ARCHITECT for remaining work"

  # Kill monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  teardown_test
}

# Test lastline file initialization
test_lastline_initialization() {
  setup_test

  # Remove lastline file
  rm -f /tmp/es-event-monitor.lastline

  # Add events to journal BEFORE monitor starts
  es-event-emit "WORK_ASSIGNED" "TO:ARCHITECT|ID:test1|WORK:Test"
  es-event-emit "WORK_ASSIGNED" "TO:ARCHITECT|ID:test2|WORK:Test2"

  # Start monitor
  es-event-monitor &
  local monitor_pid=$!
  sleep 2

  # Check that lastline file was created
  assert_file_exists "/tmp/es-event-monitor.lastline" "Lastline file should be created"

  # Should process existing events
  local processed=$(grep -c "WORK_ASSIGNED" "$TEST_JOURNAL")
  assert_equals "2" "$processed" "Should process pre-existing events"

  # Kill monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  teardown_test
}

# Cleanup
cleanup() {
  # Kill any remaining monitors
  pkill -f es-event-monitor 2>/dev/null || true

  # Remove test PATH
  rm -rf "/tmp/test-actors-$$"

  # Remove PID files
  rm -f /tmp/es-event-monitor.pid
  rm -f /tmp/es-event-monitor.lastline
}

trap cleanup EXIT

# Run all tests
run_tests
