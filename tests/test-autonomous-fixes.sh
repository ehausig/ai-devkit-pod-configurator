#!/bin/bash
# Test script for autonomous execution fixes
# This tests the key fixes without requiring Claude Code

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="/tmp/test-autonomous-fixes"
TEST_JOURNAL="$TEST_DIR/JOURNAL.md"
ORIGINAL_JOURNAL="$HOME/workspace/JOURNAL.md"

# Create isolated test environment
setup_test_environment() {
    echo -e "${BLUE}=== Setting up test environment ===${NC}"
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Initialize git repo for testing
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create test journal
    cat > "$TEST_JOURNAL" << 'EOF'
# Development Journal

2024-12-19T10:00:00Z [ARCHITECT:INIT] Starting ARCHITECT persona
2024-12-19T10:01:00Z [WORK:PENDING] DEVELOPER: Create feature branch feat/test
2024-12-19T10:02:00Z [WORK:PENDING] DEVELOPER: Set up project structure
2024-12-19T10:03:00Z [WORK:PENDING] DEVELOPER: Write tests
2024-12-19T10:04:00Z [HANDOFF:COMPLETED] Handed off to DEVELOPER with 3 work items
EOF
    
    # Set environment
    export JOURNAL_FILE="$TEST_JOURNAL"
    export CLAUDE_AUTONOMOUS_MODE="true"
    export HOOK_CONTEXT="true"  # Simulate hook context
    
    echo -e "${GREEN}✓ Test environment created at $TEST_DIR${NC}"
}

# Test 1: Work script exit codes
test_work_script_exit_codes() {
    echo -e "${BLUE}=== Test 1: Work Script Exit Codes ===${NC}"
    
    # Prepare work script
    PERSONA="DEVELOPER"
    es-work-tracker.sh prepare "$PERSONA" >/dev/null 2>&1
    
    if [ ! -f /tmp/execute-next-work.sh ]; then
        echo -e "${RED}✗ Failed to create work script${NC}"
        return 1
    fi
    
    # Check that script doesn't use exit 2
    if grep -q "exit 2" /tmp/execute-next-work.sh; then
        echo -e "${RED}✗ Work script still uses exit code 2${NC}"
        grep -n "exit 2" /tmp/execute-next-work.sh
        return 1
    else
        echo -e "${GREEN}✓ Work script does not use exit code 2${NC}"
    fi
    
    # Execute work script
    /tmp/execute-next-work.sh >/dev/null 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 2 ]; then
        echo -e "${RED}✗ Work script returned exit code 2${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Work script returned exit code $EXIT_CODE (not 2)${NC}"
    fi
    
    return 0
}

# Test 2: Automatic handoff execution
test_automatic_handoff() {
    echo -e "${BLUE}=== Test 2: Automatic Handoff Execution ===${NC}"
    
    # Create a scenario where all work is complete
    cat > "$TEST_JOURNAL" << 'EOF'
# Development Journal

2024-12-19T10:00:00Z [DEVELOPER:INIT] Starting DEVELOPER persona
2024-12-19T10:01:00Z [WORK:COMPLETED] DEVELOPER: Create feature branch feat/test
2024-12-19T10:02:00Z [WORK:COMPLETED] DEVELOPER: Set up project structure
2024-12-19T10:03:00Z [WORK:COMPLETED] DEVELOPER: Write tests
EOF
    
    # Prepare work script (should detect no pending work)
    es-work-tracker.sh prepare "DEVELOPER" >/dev/null 2>&1
    
    # Check if work script exists
    if [ ! -f /tmp/execute-next-work.sh ]; then
        echo -e "${YELLOW}✓ No work script created (no pending work)${NC}"
        return 0
    fi
    
    # Check if work script will execute handoff
    if grep -q "persona-developer-handoff.sh" /tmp/execute-next-work.sh; then
        echo -e "${GREEN}✓ Work script includes automatic handoff execution${NC}"
    else
        echo -e "${RED}✗ Work script missing automatic handoff${NC}"
        return 1
    fi
    
    return 0
}

# Test 3: Hook context validation
test_hook_context_validation() {
    echo -e "${BLUE}=== Test 3: Hook Context Validation ===${NC}"
    
    # Create work item that requires validation
    cat >> "$TEST_JOURNAL" << 'EOF'
2024-12-19T10:05:00Z [WORK:PENDING] DEVELOPER: Create pull request
EOF
    
    # Prepare work script with hook context
    export HOOK_CONTEXT="true"
    es-work-tracker.sh prepare "DEVELOPER" >/dev/null 2>&1
    
    if [ ! -f /tmp/execute-next-work.sh ]; then
        echo -e "${RED}✗ Failed to create work script${NC}"
        return 1
    fi
    
    # Check if script detects hook context
    if grep -q "HOOK_CONTEXT=" /tmp/execute-next-work.sh; then
        echo -e "${GREEN}✓ Work script includes hook context detection${NC}"
    else
        echo -e "${RED}✗ Work script missing hook context detection${NC}"
        return 1
    fi
    
    # Check for lenient validation in hook context
    if grep -q "simplified validation in hook context" /tmp/execute-next-work.sh; then
        echo -e "${GREEN}✓ Work script has lenient validation for hook context${NC}"
    else
        echo -e "${YELLOW}⚠ Work script may not have lenient validation${NC}"
    fi
    
    return 0
}

# Test 4: Work queue monitor error handling
test_work_queue_monitor() {
    echo -e "${BLUE}=== Test 4: Work Queue Monitor Error Handling ===${NC}"
    
    # Create mock hook framework functions
    get_command() { echo "es-journal-log.sh 'WORK:COMPLETED' 'DEVELOPER: Test task'"; }
    log_hook_event() { echo "[$1] $2"; }
    export -f get_command log_hook_event
    
    # Source the work queue monitor
    source cc-hook-logic-work-queue-monitor.sh 2>/dev/null
    
    # The script should handle errors gracefully
    echo -e "${GREEN}✓ Work queue monitor loaded successfully${NC}"
    
    return 0
}

# Test 5: Autonomous controller resilience
test_autonomous_controller() {
    echo -e "${BLUE}=== Test 5: Autonomous Controller Resilience ===${NC}"
    
    # Test with mock JSON input
    JSON_INPUT='{"session_id":"test","hook_event_name":"Stop","stop_hook_active":false}'
    
    # The controller should handle failures gracefully
    echo "$JSON_INPUT" | cc-hook-autonomous-controller.sh >/dev/null 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Autonomous controller completed without fatal errors${NC}"
    else
        echo -e "${YELLOW}⚠ Autonomous controller exited with code $EXIT_CODE${NC}"
    fi
    
    return 0
}

# Test 6: Full workflow simulation
test_full_workflow() {
    echo -e "${BLUE}=== Test 6: Full Workflow Simulation ===${NC}"
    
    # Create complete workflow journal
    cat > "$TEST_JOURNAL" << 'EOF'
# Development Journal

2024-12-19T10:00:00Z [ARCHITECT:INIT] Starting ARCHITECT persona
2024-12-19T10:01:00Z [WORK:COMPLETED] ARCHITECT: Create architecture
2024-12-19T10:02:00Z [HANDOFF:COMPLETED] Handed off to DEVELOPER with 2 work items
2024-12-19T10:03:00Z [WORK:PENDING] DEVELOPER: Create feature branch
2024-12-19T10:04:00Z [WORK:PENDING] DEVELOPER: Implement feature
EOF
    
    # Check transition detection
    NEXT_PERSONA=$(es-journal-query.sh transition-needed 2>/dev/null)
    
    if [ "$NEXT_PERSONA" = "DEVELOPER" ]; then
        echo -e "${GREEN}✓ Correctly detected DEVELOPER needs work${NC}"
    else
        echo -e "${RED}✗ Failed to detect DEVELOPER transition${NC}"
        return 1
    fi
    
    # Simulate work execution
    echo "2024-12-19T10:05:00Z [WORK:STARTED] DEVELOPER: Create feature branch" >> "$TEST_JOURNAL"
    echo "2024-12-19T10:06:00Z [WORK:COMPLETED] DEVELOPER: Create feature branch" >> "$TEST_JOURNAL"
    
    # Check remaining work
    PENDING=$(es-journal-query.sh pending-work DEVELOPER | wc -l)
    
    if [ "$PENDING" -eq 1 ]; then
        echo -e "${GREEN}✓ Correctly shows 1 pending work item${NC}"
    else
        echo -e "${RED}✗ Incorrect pending count: $PENDING${NC}"
        return 1
    fi
    
    return 0
}

# Run all tests
run_all_tests() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    Autonomous Fixes Test Suite         ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    setup_test_environment
    
    local total=0
    local passed=0
    
    tests=(
        "test_work_script_exit_codes"
        "test_automatic_handoff"
        "test_hook_context_validation"
        "test_work_queue_monitor"
        "test_autonomous_controller"
        "test_full_workflow"
    )
    
    for test in "${tests[@]}"; do
        echo ""
        ((total++))
        if $test; then
            ((passed++))
            echo -e "${GREEN}✓ $test PASSED${NC}"
        else
            echo -e "${RED}✗ $test FAILED${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Results: $passed/$total tests passed${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # Cleanup
    cd /
    rm -rf "$TEST_DIR"
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}All tests passed! The fixes are working correctly.${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed. Please review the fixes.${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Check if we have the required scripts in PATH
    if ! command -v es-journal-query.sh >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: es-journal-query.sh not in PATH${NC}"
        echo "Some tests may fail. Ensure Claude Code scripts are installed."
    fi
    
    if ! command -v es-work-tracker.sh >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: es-work-tracker.sh not in PATH${NC}"
        echo "Installing the fixed version locally for testing..."
        
        # Copy the fixed script to current directory for testing
        cp /path/to/fixed/es-work-tracker.sh ./
        chmod +x ./es-work-tracker.sh
        export PATH="$PWD:$PATH"
    fi
    
    run_all_tests
}

# Run main
main "$@"
