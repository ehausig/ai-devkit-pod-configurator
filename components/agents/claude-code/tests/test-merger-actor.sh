#!/bin/bash
# Test MERGER actor functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Setup test journal location
export TEST_JOURNAL="/tmp/test-journal-$$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Mock the actor base functions for testing
setup_merger_test() {
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
    # Mock command execution
    local cmd="$1"
    echo "Mock executing: $cmd"
    
    # Simulate some commands
    case "$cmd" in
        *"git checkout main"*|*"git checkout master"*)
            return 0
            ;;
        *"git merge"*)
            return 0
            ;;
        *"gh pr"*)
            return 0
            ;;
        *)
            eval "$cmd" 2>/dev/null || return 0
            ;;
    esac
}

create_file_with_content() {
    mkdir -p "$(dirname "$1")"
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

check_repository_state() {
    echo "Mock repository state check"
}
EOF
}

# Test MERGER CI/CD verification
test_merger_cicd_verification() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=0
  RELEASES_CREATED=0
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  else
    echo "merger-actor.sh not found"
    return 1
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$

  # Test CI/CD check
  execute_persona_work "test-1" "Verify all CI/CD checks pass for PR #123"
  
  local context=$(grep "MERGER:CONTEXT.*CI/CD" "$TEST_JOURNAL")
  assert_contains "$context" "CI/CD" "Should check CI/CD status"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
  rm -f /tmp/test-actor-base.sh
}

# Test MERGER merge operations
test_merger_merge_operations() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=0
  RELEASES_CREATED=0
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$
  ensure_git_repo

  # Test merge operation
  execute_persona_work "test-1" "Merge PR #123"
  
  # Should increment merge counter
  assert_equals "1" "$MERGES_COMPLETED" "Should complete merge"
  
  local memory=$(grep "MERGER:MEMORY.*merged" "$TEST_JOURNAL")
  assert_contains "$memory" "Successfully merged" "Should log successful merge"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
  rm -f /tmp/test-actor-base.sh
}

# Test MERGER changelog update
test_merger_changelog_update() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=1
  RELEASES_CREATED=0
  ISSUES_ENCOUNTERED=0
  PROJECT_TYPE="nodejs"

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$

  # Create package.json with version
  create_file_with_content "package.json" '{"version": "1.0.0"}'

  # Test changelog creation
  execute_persona_work "test-1" "Update CHANGELOG.md with version and changes"
  
  assert_file_exists "CHANGELOG.md" "Should create changelog"
  
  local changelog=$(cat CHANGELOG.md)
  assert_contains "$changelog" "## [1.0.1]" "Should increment version"
  assert_contains "$changelog" "Initial implementation" "Should describe changes"
  assert_contains "$changelog" "test suite" "Should mention tests"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
  rm -f /tmp/test-actor-base.sh
}

# Test MERGER release tagging
test_merger_release_tagging() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=1
  RELEASES_CREATED=0
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$
  ensure_git_repo

  # Create changelog with version
  create_file_with_content "CHANGELOG.md" "## [1.2.0] - 2024-01-01"

  # Test release tag creation
  execute_persona_work "test-1" "Tag release version according to semantic versioning"
  
  assert_equals "1" "$RELEASES_CREATED" "Should create release"
  
  local memory=$(grep "MERGER:MEMORY.*release tag" "$TEST_JOURNAL")
  assert_contains "$memory" "v1.2.0" "Should create version tag"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
  rm -f /tmp/test-actor-base.sh
}

# Test MERGER branch cleanup
test_merger_branch_cleanup() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=1
  RELEASES_CREATED=0
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$
  ensure_git_repo

  # Create and checkout feature branch
  git checkout -b feat/test-feature 2>/dev/null
  git checkout main 2>/dev/null || git checkout master 2>/dev/null

  # Test branch deletion
  execute_persona_work "test-1" "Delete feature branch after successful merge"
  
  local context=$(grep "MERGER:CONTEXT.*Deleted.*branches" "$TEST_JOURNAL")
  assert_contains "$context" "Deleted" "Should delete merged branches"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
  rm -f /tmp/test-actor-base.sh
}

# Test MERGER handoff logic
test_merger_handoff_logic() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=1
  RELEASES_CREATED=1
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  # Test cycle completion
  local next=$(determine_next_persona "MERGER")
  assert_contains "$next" "COMPLETE" "Should complete cycle when no more work"

  # Test with pending work
  # Add pending work for another persona
  echo "$(date -Iseconds) [EVENT] TYPE:WORK_ASSIGNED|TO:ARCHITECT|ID:123|WORK:New feature" >> "$TEST_JOURNAL"
  
  next=$(determine_next_persona "MERGER")
  assert_contains "$next" "ARCHITECT" "Should hand off to persona with pending work"

  rm -f /tmp/test-actor-base.sh
}

# Test MERGER release notes
test_merger_release_notes() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=2
  RELEASES_CREATED=1
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$

  # Create changelog
  create_file_with_content "CHANGELOG.md" "## [2.0.0] - 2024-01-01
### Added
- New feature X
- API endpoint Y"

  # Test stakeholder notification
  execute_persona_work "test-1" "Notify stakeholders of completion"
  
  assert_file_exists "RELEASE_NOTES.md" "Should create release notes"
  
  local notes=$(cat RELEASE_NOTES.md)
  assert_contains "$notes" "Merges Completed: 2" "Should show merge count"
  assert_contains "$notes" "Releases Created: 1" "Should show release count"
  assert_contains "$notes" "Version" "Should include version info"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
  rm -f /tmp/test-actor-base.sh
}

# Test MERGER integration test execution
test_merger_integration_tests() {
  setup_merger_test
  source /tmp/test-actor-base.sh

  PERSONA="MERGER"
  MERGES_COMPLETED=0
  RELEASES_CREATED=0
  ISSUES_ENCOUNTERED=0

  if [ -f "/usr/local/bin/merger-actor.sh" ]; then
    source <(grep -v "^actor_loop" /usr/local/bin/merger-actor.sh | sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' || echo "echo 'merger-actor processing failed'")
  fi

  mkdir -p /tmp/test-merger-$$
  cd /tmp/test-merger-$$
  ensure_git_repo

  # Test integration test execution
  execute_persona_work "test-1" "Run final integration tests on main branch"
  
  local context=$(grep "MERGER:CONTEXT.*Integration tests" "$TEST_JOURNAL")
  assert_contains "$context" "Integration tests" "Should run integration tests"

  # Cleanup
  cd - >/dev/null
  rm -rf /tmp/test-merger-$$
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
