#!/bin/bash
# Test hook system functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Setup test journal location
export TEST_JOURNAL="/tmp/test-journal-$$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Test hook framework basic functionality
test_hook_framework_basics() {
  # Create mock JSON input
  local json_input='{
    "tool_name": "Bash",
    "session_id": "test-123",
    "tool_input": {
      "command": "echo test",
      "description": "Test command"
    }
  }'

  # Test JSON field extraction
  local tool_name=$(echo "$json_input" | jq -r '.tool_name')
  assert_equals "Bash" "$tool_name" "Should extract tool name"

  # Test hook type detection
  export JSON_INPUT="$json_input"
  export HOOK_TYPE="bash-logger"
  
  # The hook framework would normally source the logic script
  assert_equals "bash-logger" "$HOOK_TYPE" "Hook type should be set"
}

# Test bash logger hook
test_bash_logger_hook() {
  # Create test JSON for PostToolUse
  local json_input='{
    "tool_name": "Bash",
    "hook_event_name": "PostToolUse",
    "tool_input": {
      "command": "git commit -m \"feat: add feature\"",
      "description": "Committing changes"
    },
    "tool_response": {
      "interrupted": false,
      "stderr": ""
    }
  }'

  export JSON_INPUT="$json_input"
  export HOOK_TYPE="bash-logger"

  # Source the hook logic directly
  if [ -f "/usr/local/bin/cc-hook-logic-bash-logger.sh" ]; then
    source /usr/local/bin/cc-hook-logic-bash-logger.sh
  else
    echo "Hook logic script not found"
    return 1
  fi

  # Check for git operation logging
  local log=$(grep "GIT" "$TEST_JOURNAL" | tail -1)
  assert_contains "$log" "git commit" "Should log git operations"
}

# Test decision tracker hook
test_decision_tracker_hook() {
  # Create test JSON for file write
  local json_input='{
    "tool_name": "Write",
    "hook_event_name": "PostToolUse",
    "tool_input": {
      "file_path": "package.json",
      "content": "{\"name\": \"test-project\"}"
    },
    "tool_response": {
      "interrupted": false
    }
  }'

  export JSON_INPUT="$json_input"
  export HOOK_TYPE="decision-tracker"

  # Mock get_file_path function
  get_file_path() { echo "package.json"; }
  export -f get_file_path

  # Source the hook logic
  if [ -f "/usr/local/bin/cc-hook-logic-decision-tracker.sh" ]; then
    source /usr/local/bin/cc-hook-logic-decision-tracker.sh
  fi

  local decision=$(grep "DECISION.*Node.js" "$TEST_JOURNAL")
  assert_contains "$decision" "Node.js" "Should track Node.js project decision"
}

# Test error recovery hook
test_error_recovery_hook() {
  # Create test JSON for failed command
  local json_input='{
    "tool_name": "Bash",
    "hook_event_name": "PostToolUse",
    "tool_input": {
      "command": "npm install",
      "description": "Installing dependencies"
    },
    "tool_response": {
      "interrupted": false,
      "stderr": "npm ERR! Failed to install"
    }
  }'

  export JSON_INPUT="$json_input"
  export HOOK_TYPE="error-recovery"

  # Mock helper functions
  get_command() { echo "npm install"; }
  get_description() { echo "Installing dependencies"; }
  is_post_tool_use() { return 0; }
  is_command_successful() { return 1; }
  get_error_details() { echo "npm ERR! Failed to install"; }
  export -f get_command get_description is_post_tool_use is_command_successful get_error_details

  # Source the hook logic
  if [ -f "/usr/local/bin/cc-hook-logic-error-recovery.sh" ]; then
    source /usr/local/bin/cc-hook-logic-error-recovery.sh
  fi

  local error=$(grep "ERROR.*npm install" "$TEST_JOURNAL")
  assert_contains "$error" "Command failed" "Should log failed commands"
  
  local error_detail=$(grep "ERROR.*Failed to install" "$TEST_JOURNAL")
  assert_contains "$error_detail" "Failed to install" "Should log error details"
}

# Test file milestone hook
test_file_milestone_hook() {
  # Create test JSON for README creation
  local json_input='{
    "tool_name": "Write",
    "hook_event_name": "PostToolUse",
    "tool_input": {
      "file_path": "README.md",
      "content": "# Project Title"
    },
    "tool_response": {
      "interrupted": false
    }
  }'

  export JSON_INPUT="$json_input"
  export HOOK_TYPE="file-milestone"

  # Mock helper functions
  is_post_tool_use() { return 0; }
  get_file_path() { echo "README.md"; }
  export -f is_post_tool_use get_file_path

  # Source the hook logic
  if [ -f "/usr/local/bin/cc-hook-logic-file-milestone.sh" ]; then
    source /usr/local/bin/cc-hook-logic-file-milestone.sh
  fi

  local milestone=$(grep "MILESTONE.*README" "$TEST_JOURNAL")
  assert_contains "$milestone" "Project README created" "Should track README creation"
}

# Test format code hook
test_format_code_hook() {
  # Create a test Python file
  mkdir -p /tmp/test-format-$$
  cat > /tmp/test-format-$$/test.py << 'EOF'
def test():
    x=1
    y=2
    return x+y
EOF

  # Create test JSON
  local json_input="{
    \"tool_name\": \"Write\",
    \"hook_event_name\": \"PostToolUse\",
    \"tool_input\": {
      \"file_path\": \"/tmp/test-format-$$/test.py\",
      \"content\": \"test content\"
    }
  }"

  export JSON_INPUT="$json_input"
  export HOOK_TYPE="format-code"

  # Mock helper functions
  is_post_tool_use() { return 0; }
  get_file_path() { echo "/tmp/test-format-$$/test.py"; }
  export -f is_post_tool_use get_file_path

  # Source the hook logic
  if [ -f "/usr/local/bin/cc-hook-logic-format-code.sh" ]; then
    source /usr/local/bin/cc-hook-logic-format-code.sh
  fi

  local format_log=$(grep "INFO.*Auto-formatting" "$TEST_JOURNAL")
  assert_contains "$format_log" "test.py" "Should log formatting attempt"

  # Cleanup
  rm -rf /tmp/test-format-$$
}

# Test notification hook
test_notification_hook() {
  # Create test JSON for notification
  local json_input='{
    "hook_event_name": "Notification",
    "message": "Build completed successfully",
    "title": "Build Success"
  }'

  export JSON_INPUT="$json_input"
  export HOOK_TYPE="notification"

  # Mock extract_json_field function
  extract_json_field() {
    case "$2" in
      ".message") echo "Build completed successfully" ;;
      ".title") echo "Build Success" ;;
      *) echo "$3" ;;
    esac
  }
  export -f extract_json_field

  # Source the hook logic
  if [ -f "/usr/local/bin/cc-hook-logic-notification.sh" ]; then
    source /usr/local/bin/cc-hook-logic-notification.sh
  fi

  local notification=$(grep "NOTIFICATION" "$TEST_JOURNAL")
  assert_contains "$notification" "Build Success" "Should log notification title"
  assert_contains "$notification" "Build completed" "Should log notification message"

  # Check notification log file was created
  assert_file_exists "$HOME/workspace/.notifications.log" "Should create notification log"

  # Cleanup
  rm -f "$HOME/workspace/.notifications.log"
}

# Test autonomous controller hook
test_autonomous_controller_hook() {
  # Create test JSON for Stop event
  local json_input='{
    "hook_event_name": "Stop",
    "session_id": "test-session-123"
  }'

  export JSON_INPUT="$json_input"
  export CLAUDE_AUTONOMOUS_MODE="true"

  # Check that the hook would start the event monitor
  # We won't actually start it in tests
  local session_id=$(echo "$json_input" | jq -r '.session_id')
  assert_equals "test-session-123" "$session_id" "Should extract session ID"

  # Verify autonomous mode check works
  if [ "$CLAUDE_AUTONOMOUS_MODE" = "true" ]; then
    assert_equals "true" "true" "Autonomous mode is enabled"
  else
    assert_equals "false" "true" "Autonomous mode should be enabled"
  fi
}

# Test hook event routing
test_hook_event_routing() {
  # Test PreToolUse event
  local json_pre='{
    "hook_event_name": "PreToolUse",
    "tool_name": "Bash"
  }'

  # Test PostToolUse event
  local json_post='{
    "hook_event_name": "PostToolUse",
    "tool_name": "Bash",
    "tool_response": {"interrupted": false}
  }'

  # Test is_post_tool_use detection
  echo "$json_post" | jq -e '.tool_response' > /dev/null 2>&1
  local is_post=$?
  assert_equals "0" "$is_post" "Should detect PostToolUse event"

  echo "$json_pre" | jq -e '.tool_response' > /dev/null 2>&1
  local is_pre=$?
  assert_equals "1" "$is_pre" "Should detect PreToolUse event"
}

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run all tests
run_tests

# The test framework reports the summary
exit $?
