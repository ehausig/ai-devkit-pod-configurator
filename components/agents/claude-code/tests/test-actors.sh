#!/bin/bash
# Test actor functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Kill any existing processes that might interfere
kill_actor_test_processes() {
  pkill -f "architect-actor.sh" 2>/dev/null || true
  pkill -f "developer-actor.sh" 2>/dev/null || true
  pkill -f "qa-actor.sh" 2>/dev/null || true
  pkill -f "reviewer-actor.sh" 2>/dev/null || true
  pkill -f "merger-actor.sh" 2>/dev/null || true
  pkill -f "test-actor-base.sh" 2>/dev/null || true
  rm -f /tmp/test-actor-base.sh
  rm -rf /tmp/test-project-*
  rm -rf /tmp/test-handoff-*
  rm -rf /tmp/test-patterns-*
  sleep 0.5
}

# Initial cleanup
kill_actor_test_processes

# Setup test journal location globally for this test suite
export TEST_JOURNAL="/tmp/test-journal-$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Mock the actor base functions for testing
setup_actor_test() {
  # Ensure JOURNAL_FILE is exported
  export JOURNAL_FILE="$TEST_JOURNAL"

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
    echo "$2" > "$1"
}

run_tests() {
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

# Test ARCHITECT actor work execution
test_architect_work_execution() {
  # Create mock actor base
  setup_actor_test

  # Source mock base
  source /tmp/test-actor-base.sh

  # Source architect actor functions (without running actor_loop)
  PERSONA="ARCHITECT"

  # Check if script exists in /usr/local/bin first
  if [ -f "/usr/local/bin/architect-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/architect-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'architect-actor processing failed'")
  else
    echo "architect-actor.sh not found in /usr/local/bin"
    # Clean up before returning
    rm -f /tmp/test-actor-base.sh
    return 1
  fi

  # Test architecture creation
  local work_id="test-1"
  local work_desc="Create system architecture based on requirements"

  # Create a test directory
  mkdir -p /tmp/test-project-$$
  cd /tmp/test-project-$$

  # Execute work
  execute_persona_work "$work_id" "$work_desc"
  local result=$?

  assert_exit_code 0 $result "Architecture creation should succeed"
  assert_file_exists "ARCHITECTURE.md" "Architecture file should be created"

  # Check decisions were logged
  local decisions=$(grep "ARCHITECT:DECISION" "$TEST_JOURNAL")
  assert_contains "$decisions" "Creating system architecture" "Should log architecture decision"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-project-$$
  rm -f /tmp/test-actor-base.sh
}

# Test DEVELOPER actor work execution
test_developer_work_execution() {
  # Setup mock base (inline to avoid setup_actor_test)
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
    echo "$2" > "$1"
}

run_tests() {
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

  # Source mock base
  source /tmp/test-actor-base.sh

  # Source developer actor functions
  PERSONA="DEVELOPER"
  PROJECT_TYPE="python" # Set project type for testing

  if [ -f "/usr/local/bin/developer-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/developer-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'developer-actor processing failed'")
  else
    echo "developer-actor.sh not found in /usr/local/bin"
    rm -f /tmp/test-actor-base.sh
    return 1
  fi

  # Create test directory
  mkdir -p /tmp/test-project-$$
  cd /tmp/test-project-$$

  # Test project initialization
  execute_persona_work "test-1" "Initialize project with python tooling"
  assert_file_exists "requirements.txt" "Requirements file should be created"

  # Test structure creation
  execute_persona_work "test-2" "Set up project structure with src/ and tests/ directories"
  assert_file_exists "src/__init__.py" "Source package should be created"
  assert_file_exists "tests/__init__.py" "Tests package should be created"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-project-$$
  rm -f /tmp/test-actor-base.sh
}

# Test handoff logic
test_handoff_generation() {
  # Create mock base inline
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
    echo "$2" > "$1"
}

run_tests() {
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

  # Source mock base
  source /tmp/test-actor-base.sh

  # Test ARCHITECT to DEVELOPER handoff
  PERSONA="ARCHITECT"

  # Create required files for handoff
  mkdir -p /tmp/test-handoff-$$
  cd /tmp/test-handoff-$$
  touch ARCHITECTURE.md API_DESIGN.md DATA_MODELS.md TESTING_STRATEGY.md

  if [ -f "/usr/local/bin/architect-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/architect-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'architect-actor processing failed'")
  fi

  # Test handoff determination
  local next=$(determine_next_persona "ARCHITECT")
  assert_contains "$next" "DEVELOPER" "Should handoff to DEVELOPER when docs complete"

  # Generate work items
  local work_items=$(generate_work_items "ARCHITECT" "DEVELOPER")

  assert_contains "$work_items" "feature branch" "Should create branch task"
  assert_contains "$work_items" "project structure" "Should create structure task"
  assert_contains "$work_items" "tests" "Should create test tasks"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-handoff-$$
  rm -f /tmp/test-actor-base.sh
}

# Test next persona determination
test_next_persona_logic() {
  # Create mock base inline
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
    echo "$2" > "$1"
}

run_tests() {
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

  # Source mock base
  source /tmp/test-actor-base.sh

  # Test QA decision logic
  PERSONA="QA"
  TESTS_FAILED=0
  ISSUES_FOUND=0

  if [ -f "/usr/local/bin/qa-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/qa-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'qa-actor processing failed'")
  fi

  # Test with no failures
  local next=$(determine_next_persona "QA")
  assert_contains "$next" "REVIEWER" "QA should hand off to REVIEWER when tests pass"

  # Test with failures
  TESTS_FAILED=1
  next=$(determine_next_persona "QA")
  assert_contains "$next" "DEVELOPER" "QA should hand off to DEVELOPER when tests fail"

  rm -f /tmp/test-actor-base.sh
}

# Test logging functions
test_persona_logging() {
  # Create mock base inline
  cat >/tmp/test-actor-base.sh <<'EOF'
#!/bin/bash
# Mock actor base for testing

ACTOR_ACTIVE=true
PERSONA="TEST"
JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"

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
EOF

  # Source mock base
  source /tmp/test-actor-base.sh

  # Test logging functions
  log_decision "Chose Python for implementation"
  log_issue "Tests failing with timeout"
  log_memory "API uses port 8080"
  log_context "Starting implementation phase"

  # Verify logs
  assert_contains "$(cat $TEST_JOURNAL)" "DECISION] Chose Python" "Decision should be logged"
  assert_contains "$(cat $TEST_JOURNAL)" "ISSUE] Tests failing" "Issue should be logged"
  assert_contains "$(cat $TEST_JOURNAL)" "MEMORY] API uses" "Memory should be logged"
  assert_contains "$(cat $TEST_JOURNAL)" "CONTEXT] Starting" "Context should be logged"

  rm -f /tmp/test-actor-base.sh
}

# Test complete workflow simulation
test_workflow_simulation() {
  # Simulate ARCHITECT creating work for DEVELOPER
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:1|WORK:Create feature branch"
  es-event-emit.sh "WORK_ASSIGNED" "TO:DEVELOPER|ID:2|WORK:Implement feature"
  es-event-emit.sh "HANDOFF_READY" "FROM:ARCHITECT|TO:DEVELOPER|COUNT:2"

  # Simulate DEVELOPER completing work
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:1"
  es-event-emit.sh "WORK_COMPLETED" "PERSONA:DEVELOPER|WORK_ID:2"

  # Create QA work
  es-event-emit.sh "WORK_ASSIGNED" "TO:QA|ID:3|WORK:Run tests"
  es-event-emit.sh "HANDOFF_READY" "FROM:DEVELOPER|TO:QA|COUNT:1"

  # Verify journal state
  local dev_pending=$(es-projection.sh "DEVELOPER" "pending_work" | wc -l)
  assert_equals "0" "$dev_pending" "DEVELOPER should have no pending work"

  local qa_pending=$(es-projection.sh "QA" "pending_work" | wc -l)
  assert_equals "1" "$qa_pending" "QA should have 1 pending work item"
}

# Test work pattern matching
test_work_pattern_matching() {
  setup_actor_test

  # Source mock base
  source /tmp/test-actor-base.sh

  # Test various work descriptions
  PERSONA="ARCHITECT"

  # Create test directory
  mkdir -p /tmp/test-patterns-$$
  cd /tmp/test-patterns-$$

  if [ -f "/usr/local/bin/architect-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/architect-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'architect-actor processing failed'")
  else
    echo "architect-actor.sh not found in /usr/local/bin"
    rm -f /tmp/test-actor-base.sh
    return 1
  fi

  # Test patterns that should work
  execute_persona_work "t1" "Create system architecture for web app"
  assert_file_exists "ARCHITECTURE.md" "Should match 'Create system architecture' pattern"
  rm -f ARCHITECTURE.md

  execute_persona_work "t2" "Design API specification"
  assert_file_exists "API_DESIGN.md" "Should match 'API design' pattern"
  rm -f API_DESIGN.md

  execute_persona_work "t3" "Define data models and schemas"
  assert_file_exists "DATA_MODELS.md" "Should match 'data model' pattern"
  rm -f DATA_MODELS.md

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-patterns-$$
  rm -f /tmp/test-actor-base.sh
}

# Initialize test counters for this file
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test all functions
run_tests

# Clean up any remaining processes
pkill -f "test-journal-$" 2>/dev/null || true

# The test framework already reports the summary, so just exit
exit $?
