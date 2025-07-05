#!/bin/bash
# Test script for multi-persona system - Fixed version
# This script validates core functionality of the persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test directories
TEST_DIR="/tmp/persona-test-$$"
JOURNAL_BACKUP=""

# Function to print test header
print_test_header() {
    echo ""
    echo -e "${BLUE}=== Testing: $1 ===${NC}"
}

# Function to assert command exists
assert_command_exists() {
    local cmd=$1
    local desc=$2
    ((TESTS_TOTAL++))
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $desc"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc - Command not found: $cmd"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to assert file exists
assert_file_exists() {
    local file=$1
    local desc=$2
    ((TESTS_TOTAL++))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $desc"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc - File not found: $file"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to assert command succeeds
assert_command_succeeds() {
    local cmd=$1
    local desc=$2
    ((TESTS_TOTAL++))
    
    if eval "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $desc"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc - Command failed: $cmd"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to assert output contains
assert_output_contains() {
    local cmd=$1
    local expected=$2
    local desc=$3
    ((TESTS_TOTAL++))
    
    local output=$(eval "$cmd" 2>&1)
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $desc"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc - Expected '$expected' in output"
        echo "  Command: $cmd"
        echo "  Output: $(echo "$output" | head -3)..."
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to assert output contains (case insensitive)
assert_output_contains_i() {
    local cmd=$1
    local expected=$2
    local desc=$3
    ((TESTS_TOTAL++))
    
    local output=$(eval "$cmd" 2>&1)
    if echo "$output" | grep -iq "$expected"; then
        echo -e "${GREEN}✓${NC} $desc"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc - Expected '$expected' in output (case insensitive)"
        echo "  Command: $cmd"
        echo "  Output: $(echo "$output" | head -3)..."
        ((TESTS_FAILED++))
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Backup existing journal if it exists
    if [ -f "$HOME/workspace/JOURNAL.md" ]; then
        JOURNAL_BACKUP="$HOME/workspace/JOURNAL.md.backup-$$"
        cp "$HOME/workspace/JOURNAL.md" "$JOURNAL_BACKUP"
    fi
    
    # Create test journal
    mkdir -p "$HOME/workspace"
    echo "# Test Journal" > "$HOME/workspace/JOURNAL.md"
}

# Cleanup test environment
cleanup_test_env() {
    cd /
    rm -rf "$TEST_DIR"
    
    # Restore journal backup if it exists
    if [ -n "$JOURNAL_BACKUP" ] && [ -f "$JOURNAL_BACKUP" ]; then
        mv "$JOURNAL_BACKUP" "$HOME/workspace/JOURNAL.md"
    else
        rm -f "$HOME/workspace/JOURNAL.md"
    fi
    
    # Clean up any test artifacts
    rm -f /tmp/execute-next-work.sh
    rm -f /tmp/persona-work-ready
}

# Trap to ensure cleanup
trap cleanup_test_env EXIT

# Main test execution
main() {
    echo -e "${BLUE}Multi-Persona System Test Suite (Fixed)${NC}"
    echo "========================================"
    
    setup_test_env
    
    # Test 1: Core Scripts Existence
    print_test_header "Core Scripts Existence"
    assert_command_exists "journal-log.sh" "journal-log.sh is available"
    assert_command_exists "journal-query.sh" "journal-query.sh is available"
    assert_command_exists "work-tracker.sh" "work-tracker.sh is available"
    assert_command_exists "get-context-window.sh" "get-context-window.sh is available"
    assert_command_exists "hook-framework.sh" "hook-framework.sh is available"
    
    # Test 2: Common Functions Library
    print_test_header "Common Functions Library"
    assert_file_exists "/usr/local/bin/claude-code-common.sh" "claude-code-common.sh exists"
    assert_command_succeeds "source /usr/local/bin/claude-code-common.sh" "Can source common functions"
    
    # Test 3: Journal Operations
    print_test_header "Journal Operations"
    assert_command_succeeds "journal-log.sh 'TEST:ENTRY' 'Test message'" "Can write to journal"
    assert_output_contains "cat $HOME/workspace/JOURNAL.md" "TEST:ENTRY" "Journal contains test entry"
    
    # Test 4: Journal Queries
    print_test_header "Journal Query Types"
    assert_command_succeeds "journal-query.sh pending-work DEVELOPER" "Can query pending work"
    assert_command_succeeds "journal-query.sh recent-context DEVELOPER" "Can query recent context"
    assert_command_succeeds "journal-query.sh handoff-ready DEVELOPER" "Can check handoff readiness"
    assert_command_succeeds "journal-query.sh safety-check DEVELOPER" "Can check safety status"
    assert_command_succeeds "journal-query.sh decisions ARCHITECT" "Can query decisions"
    assert_command_succeeds "journal-query.sh memory ARCHITECT" "Can query memories"
    assert_command_succeeds "journal-query.sh errors DEVELOPER" "Can query errors"
    assert_command_succeeds "journal-query.sh handoff-chain" "Can query handoff chain"
    assert_command_succeeds "journal-query.sh current-persona" "Can get current persona"
    assert_command_succeeds "journal-query.sh work-summary DEVELOPER" "Can get work summary"
    assert_command_succeeds "journal-query.sh stats all 7" "Can get journal statistics"
    
    # Test 5: Work Management (Fixed)
    print_test_header "Work Management Commands"
    
    # Add some test work
    journal-log.sh "WORK:PENDING" "DEVELOPER: Test work item"
    
    # Use case-insensitive match for "Pending Work Items:"
    assert_output_contains_i "work-tracker.sh status DEVELOPER" "Pending Work Items:" "Work tracker shows pending work"
    assert_command_succeeds "work-tracker.sh track 'Test work' DEVELOPER" "Can track work patterns"
    assert_command_succeeds "work-tracker.sh prepare DEVELOPER" "Can prepare work script"
    assert_file_exists "/tmp/execute-next-work.sh" "Work script is created"
    
    # Test 6: Persona Scripts (Local)
    print_test_header "Persona Scripts (Source Location)"
    for persona in architect developer qa reviewer merger; do
        assert_file_exists "/home/devuser/.claude/personas/$persona/$persona-init.sh" "$persona init script exists"
        assert_file_exists "/home/devuser/.claude/personas/$persona/$persona-handoff.sh" "$persona handoff script exists"
        assert_file_exists "/home/devuser/.claude/personas/$persona/$(echo $persona | tr '[:lower:]' '[:upper:]')-PROTOCOL.md" "$persona protocol exists"
    done
    
    # Test 6b: Persona Scripts (Deployed to /usr/local/bin)
    print_test_header "Persona Scripts (Deployed Location)"
    for persona in architect developer qa reviewer merger; do
        assert_command_exists "$persona-init.sh" "$persona-init.sh is available in PATH"
        assert_command_exists "$persona-handoff.sh" "$persona-handoff.sh is available in PATH"
        assert_file_exists "/usr/local/bin/$persona-init.sh" "$persona-init.sh exists in /usr/local/bin"
        assert_file_exists "/usr/local/bin/$persona-handoff.sh" "$persona-handoff.sh exists in /usr/local/bin"
    done
    
    # Test 7: Hook Scripts
    print_test_header "Hook Scripts"
    local hooks=(
        "bash-logger"
        "decision-tracker"
        "error-recovery"
        "file-milestone"
        "format-code"
        "journal"
        "notification"
        "persona-manager"
        "project-lifecycle"
        "session-tracker"
        "test-tracker"
        "work-queue-monitor"
    )
    
    for hook in "${hooks[@]}"; do
        assert_file_exists "/home/devuser/.claude/hooks/$hook.sh" "$hook hook script exists"
        assert_file_exists "/usr/local/bin/$hook-hook.sh" "$hook hook logic exists"
    done
    
    # Test 8: Hook Framework
    print_test_header "Hook Framework"
    
    # Create a test JSON input
    cat > /tmp/test-hook-input.json << 'EOF'
{
    "tool_name": "Bash",
    "session_id": "test-session",
    "tool_input": {
        "command": "echo test",
        "description": "Test command"
    }
}
EOF
    
    # Test hook framework with different hook types
    for hook in bash-logger session-tracker; do
        assert_command_succeeds "cat /tmp/test-hook-input.json | hook-framework.sh $hook" "Hook framework handles $hook"
    done
    
    # Test 9: Context Window (Fixed)
    print_test_header "Context Window"
    
    # Add some context
    journal-log.sh "DEVELOPER:INIT" "Starting developer"
    journal-log.sh "DEVELOPER:CONTEXT" "Test context"
    journal-log.sh "HANDOFF:COMPLETED" "Handed off to DEVELOPER"
    
    # Just check that the command succeeds and produces output
    assert_command_succeeds "get-context-window.sh DEVELOPER 10" "Context window command succeeds"
    assert_output_contains "get-context-window.sh DEVELOPER 10" "Context" "Context window produces output"
    
    # Test 10: Work Flow Integration
    print_test_header "Work Flow Integration"
    
    # Clear journal
    echo "# Test Journal" > "$HOME/workspace/JOURNAL.md"
    
    # Simulate a work flow
    journal-log.sh "ARCHITECT:INIT" "Starting architect"
    journal-log.sh "WORK:PENDING" "DEVELOPER: Create test module"
    journal-log.sh "HANDOFF:COMPLETED" "Handed off to DEVELOPER with 1 work items"
    
    assert_output_contains "journal-query.sh pending-work DEVELOPER" "Create test module" "Pending work is tracked"
    assert_output_contains "journal-query.sh handoff-chain" "Handed off to DEVELOPER" "Handoff is recorded"
    
    # Test 11: Safety Checks
    print_test_header "Safety Checks"
    
    # Add multiple inits to test safety
    for i in {1..5}; do
        journal-log.sh "DEVELOPER:INIT" "Init $i"
    done
    
    assert_output_contains "journal-query.sh safety-check DEVELOPER" "Iterations: 5" "Safety check counts iterations"
    
    # Test 12: Error Handling
    print_test_header "Error Handling"
    
    assert_output_contains "journal-query.sh invalid-query 2>&1" "Usage:" "Invalid query shows usage"
    assert_output_contains "work-tracker.sh invalid-command 2>&1" "Usage:" "Invalid command shows usage"
    
    # Test 13: Backward Compatibility
    print_test_header "Backward Compatibility"
    
    # These should still work via wrappers
    assert_command_exists "work-status.sh" "work-status.sh wrapper exists"
    assert_command_exists "prepare-next-work.sh" "prepare-next-work.sh wrapper exists"
    
    # Test 14: Work Tracker Subcommands
    print_test_header "Work Tracker Subcommands"
    
    # Test that all subcommands are recognized
    assert_command_succeeds "work-tracker.sh status" "work-tracker status subcommand works"
    assert_command_succeeds "work-tracker.sh prepare" "work-tracker prepare subcommand works"
    assert_output_contains "work-tracker.sh track 2>&1" "Usage:" "work-tracker track requires pattern"
    
    # Test 15: Persona Script Integration
    print_test_header "Persona Script Integration"
    
    # Test that init scripts can be executed (in a safe way - just check help/protocol display)
    for persona in architect developer qa reviewer merger; do
        # Running with --show-protocol should display the protocol without changing state
        assert_output_contains "$persona-init.sh --show-protocol 2>&1" "PROTOCOL" "$persona-init.sh can display protocol"
    done
    
    # Clean up test work script
    rm -f /tmp/execute-next-work.sh
    rm -f /tmp/test-hook-input.json
    
    # Summary
    echo ""
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}All tests passed! ✓${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}Some tests failed! ✗${NC}"
        echo ""
        echo "Run ./debug-test-failures.sh to see detailed output"
        return 1
    fi
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
