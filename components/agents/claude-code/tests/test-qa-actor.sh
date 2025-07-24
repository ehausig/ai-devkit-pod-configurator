#!/bin/bash
# Test QA actor functionality

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Setup test journal location
export TEST_JOURNAL="/tmp/test-journal-$$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Set TEST_MODE to prevent actor_loop from running
export TEST_MODE=1

# Test QA unit test execution
test_qa_unit_test_execution() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Verify actor loaded in test mode
    if [ "$ACTOR_RUNTIME_MODE" != "test" ]; then
        assert_equals "test" "$ACTOR_RUNTIME_MODE" "Actor should be in test mode"
        return 1
    fi
    
    # Initialize test environment
    test_init_qa "pytest"
    
    # Create test directory
    mkdir -p /tmp/test-qa-$$
    cd /tmp/test-qa-$$

    # Test unit test execution
    execute_persona_work "test-1" "Run unit test suite and verify coverage meets 80% minimum"
    assert_work_executed "$?" "Run unit tests"

    # Cleanup
    cd - >/dev/null
    rm -rf /tmp/test-qa-$$
}

# Test QA coverage verification
test_qa_coverage_verification() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Initialize
    test_init_qa "jest/npm"

    mkdir -p /tmp/test-qa-$$
    cd /tmp/test-qa-$$

    # Test coverage check
    execute_persona_work "test-1" "Verify test coverage meets 80% minimum"
    assert_work_executed "$?" "Verify coverage"

    # Cleanup
    cd - >/dev/null
    rm -rf /tmp/test-qa-$$
}

# Test QA integration testing
test_qa_integration_testing() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Initialize
    test_init_qa "pytest"

    mkdir -p /tmp/test-qa-$$
    cd /tmp/test-qa-$$

    # Test integration testing
    execute_persona_work "test-1" "Run integration tests against REAL services (no mocks)"
    assert_work_executed "$?" "Run integration tests"
    
    # Verify the memory was logged
    local memory=$(grep "QA:MEMORY.*real services" "$TEST_JOURNAL")
    assert_contains "$memory" "real services" "Should log use of real services"

    # Cleanup
    cd - >/dev/null
    rm -rf /tmp/test-qa-$$
}

# Test QA error handling verification
test_qa_error_handling() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Initialize
    test_init_qa

    mkdir -p /tmp/test-qa-$$/src
    cd /tmp/test-qa-$$

    # Create source files without error handling
    echo "function test() { return data; }" > src/test.js

    # Test error handling check
    execute_persona_work "test-1" "Test error handling and edge cases"
    assert_work_executed "$?" "Test error handling"
    
    # Verify issue was found
    assert_equals "1" "$ISSUES_FOUND" "Should find error handling issues"

    # Cleanup
    cd - >/dev/null
    rm -rf /tmp/test-qa-$$
}

# Test QA report generation
test_qa_report_generation() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Initialize with some test results
    test_init_qa
    TESTS_PASSED=5
    TESTS_FAILED=1
    ISSUES_FOUND=2

    mkdir -p /tmp/test-qa-$$
    cd /tmp/test-qa-$$

    # Test report creation
    execute_persona_work "test-1" "Document any bugs or issues found"
    assert_work_executed "$?" "Generate QA report"
    
    assert_file_exists "QA_REPORT.md" "QA report should be created"

    # Cleanup
    cd - >/dev/null
    rm -rf /tmp/test-qa-$$
}

# Test QA handoff decision logic
test_qa_handoff_logic() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Initialize
    test_init_qa
    TESTS_FAILED=0
    ISSUES_FOUND=0

    # Test successful path
    local next=$(determine_next_persona "QA")
    assert_equals "REVIEWER:All tests passed, ready for code review" "$next" "Should hand off to REVIEWER when tests pass"

    # Test failure path
    TESTS_FAILED=2
    next=$(determine_next_persona "QA")
    assert_contains "$next" "DEVELOPER" "Should hand off to DEVELOPER when tests fail"
}

# Test QA work item generation
test_qa_work_generation() {
    # Set up test mode
    export TEST_MODE=1
    
    # Source the QA actor in test mode
    source /usr/local/bin/qa-actor.sh
    
    # Initialize
    test_init_qa
    TESTS_FAILED=2
    ISSUES_FOUND=1

    # Generate work for DEVELOPER
    local work_items=$(generate_work_items "QA" "DEVELOPER")
    
    assert_contains "$work_items" "Fix failing tests" "Should generate fix tasks for failed tests"
    assert_contains "$work_items" "Fix issue" "Should generate fix tasks for issues"

    # Generate work for REVIEWER
    TESTS_FAILED=0
    ISSUES_FOUND=0
    work_items=$(generate_work_items "QA" "REVIEWER")
    
    assert_contains "$work_items" "Clone PR branch" "Should generate review tasks"
    assert_contains "$work_items" "code quality checks" "Should include quality checks"
}

# Run all tests
if run_tests; then
    exit 0
else
    exit 1
fi
