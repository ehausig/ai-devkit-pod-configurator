#!/bin/bash
# QA Persona Handoff Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== QA Handoff Process ===${NC}"
echo ""

# Determine next persona based on test results
echo -e "${YELLOW}Analyzing test results...${NC}"

# Count test results from journal
PASSED=$(es-journal-query.sh recent-context QA | grep -c "QA:PASSED" || echo "0")
FAILED=$(es-journal-query.sh recent-context QA | grep -c "QA:FAILED" || echo "0")
ISSUES=$(es-journal-query.sh recent-context QA | grep -c "QA:ISSUE" || echo "0")

echo "Test Summary:"
echo "- Tests passed: $PASSED"
echo "- Tests failed: $FAILED"
echo "- Issues found: $ISSUES"
echo ""

# Determine next persona
if [ "$FAILED" -eq 0 ] && [ "$ISSUES" -eq 0 ]; then
    NEXT_PERSONA="REVIEWER"
    echo -e "${GREEN}All tests passed! Ready for code review.${NC}"
    es-journal-log.sh "HANDOFF:REQUEST" "QA requesting handoff to REVIEWER - all tests passed"
else
    NEXT_PERSONA="DEVELOPER"
    echo -e "${YELLOW}Issues found. Returning to DEVELOPER for fixes.${NC}"
    es-journal-log.sh "HANDOFF:REQUEST" "QA requesting handoff to DEVELOPER - $FAILED failures, $ISSUES issues"
fi

# Check for pending work
echo ""
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_CHECK=$(es-journal-query.sh handoff-ready QA)
HANDOFF_READY=$?

if [ $HANDOFF_READY -ne 0 ]; then
    echo -e "${RED}$PENDING_CHECK${NC}"
    es-journal-log.sh "HANDOFF:BLOCKED" "QA has incomplete test items"
    exit 1
fi

echo -e "${GREEN}✓${NC} All test items completed"

# Validate testing completeness
echo ""
echo -e "${YELLOW}Validating test coverage...${NC}"
READY=true
MISSING=""

# Check for unit test execution
if es-journal-query.sh recent-context QA | grep -q -E "(unit test|Unit test)"; then
    echo -e "${GREEN}✓${NC} Unit tests executed"
else
    echo -e "${YELLOW}⚠${NC} No unit test execution logged"
    MISSING="$MISSING unit-tests"
fi

# Check for integration test execution
if es-journal-query.sh recent-context QA | grep -q -E "(integration test|Integration test)"; then
    echo -e "${GREEN}✓${NC} Integration tests executed"
else
    echo -e "${YELLOW}⚠${NC} No integration test execution logged"
    MISSING="$MISSING integration-tests"
fi

# Check for real service testing
if es-journal-query.sh recent-context QA | grep -q -E "(real.*service|service.*real|running.*backend|backend.*running)"; then
    echo -e "${GREEN}✓${NC} Tested against real services"
else
    echo -e "${RED}✗${NC} No evidence of real service testing"
    READY=false
    MISSING="$MISSING real-service-testing"
fi

if [ "$READY" = false ]; then
    echo ""
    echo -e "${RED}ERROR: Testing incomplete. Missing: $MISSING${NC}"
    es-journal-log.sh "HANDOFF:BLOCKED" "Testing requirements not met: $MISSING"
    exit 1
fi

# Validation passed
es-journal-log.sh "HANDOFF:VALIDATED" "All QA requirements met"

echo ""
echo -e "${GREEN}Testing complete. Creating work items for $NEXT_PERSONA...${NC}"
echo ""

# Create test report
echo -e "${YELLOW}Creating test report...${NC}"

# Get test details
TEST_DETAILS=$(es-journal-query.sh recent-context QA | grep -E "(PASSED|FAILED|ISSUE)")
COVERAGE_INFO=$(es-journal-query.sh recent-context QA | grep -i "coverage" | tail -1)

cat > TEST_REPORT.md << EOF
# QA Test Report

## Date: $(date -Iseconds)

## Test Summary
- Total Tests Passed: $PASSED
- Total Tests Failed: $FAILED
- Issues Found: $ISSUES
- Decision: Handoff to $NEXT_PERSONA

## Test Execution
### Unit Tests
$(es-journal-query.sh recent-context QA | grep -E "unit.*test" | sed 's/.*\] /- /' | tail -5 || echo "- No unit test results logged")

### Integration Tests
$(es-journal-query.sh recent-context QA | grep -E "integration.*test" | sed 's/.*\] /- /' | tail -5 || echo "- No integration test results logged")

### User Simulation Tests
$(es-journal-query.sh recent-context QA | grep -E "(simulation|user|TUI|e2e)" | sed 's/.*\] /- /' | tail -5 || echo "- No user simulation results logged")

## Test Coverage
$([ -n "$COVERAGE_INFO" ] && echo "$COVERAGE_INFO" | sed 's/.*\] //' || echo "Coverage information not available")

## Issues Found
$(es-journal-query.sh recent-context QA | grep "QA:ISSUE" | sed 's/.*\[QA:ISSUE\] /- /' || echo "No issues found")

## Failed Tests
$(es-journal-query.sh recent-context QA | grep "QA:FAILED" | sed 's/.*\[QA:FAILED\] /- /' || echo "No test failures")

## Testing Environment
- Real services were used for integration testing
- All tests executed in proper environment
EOF

# Create work items based on next persona
if [ "$NEXT_PERSONA" = "REVIEWER" ]; then
    echo "## Recommendation" >> TEST_REPORT.md
    echo "All tests pass. Ready for code review." >> TEST_REPORT.md
    
    # Create work items for REVIEWER
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Clone PR branch to review directory"
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Run automated code quality checks (lint, security)"
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Review code against architectural decisions"
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Check test quality and coverage"
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Verify error handling and edge cases"
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Review documentation completeness"
    es-journal-log.sh "WORK:PENDING" "REVIEWER: Provide feedback or approve PR"
    
    WORK_COUNT=7
    cp TEST_REPORT.md HANDOFF_TO_REVIEWER.md
    
else
    echo "## Required Fixes" >> TEST_REPORT.md
    echo "The following issues need to be addressed:" >> TEST_REPORT.md
    
    # Create specific work items for DEVELOPER based on failures
    if [ $FAILED -gt 0 ]; then
        # Analyze failures and create work items
        es-journal-query.sh recent-context QA | grep "QA:FAILED" | while read -r failure; do
            failure_desc=$(echo "$failure" | sed 's/.*\[QA:FAILED\] //')
            es-journal-log.sh "WORK:PENDING" "DEVELOPER: Fix failing test - $failure_desc"
        done
    fi
    
    if [ $ISSUES -gt 0 ]; then
        # Create work items for each issue
        es-journal-query.sh recent-context QA | grep "QA:ISSUE" | while read -r issue; do
            issue_desc=$(echo "$issue" | sed 's/.*\[QA:ISSUE\] //')
            es-journal-log.sh "WORK:PENDING" "DEVELOPER: Address issue - $issue_desc"
        done
    fi
    
    # Always add re-test item
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Run all tests locally to verify fixes"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Update PR with fixes"
    
    WORK_COUNT=$(es-journal-query.sh pending-work DEVELOPER | wc -l)
    cp TEST_REPORT.md HANDOFF_TO_DEVELOPER.md
fi

echo -e "${GREEN}Created TEST_REPORT.md${NC}"
echo -e "${GREEN}Created $WORK_COUNT work items for $NEXT_PERSONA${NC}"

# Complete handoff
es-journal-log.sh "HANDOFF:COMPLETED" "Handed off to $NEXT_PERSONA with $WORK_COUNT work items"
es-journal-log.sh "QA:CONTEXT" "Testing complete. $PASSED passed, $FAILED failed, $ISSUES issues found"

echo ""
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo -e "${YELLOW}$NEXT_PERSONA should now:${NC}"
echo "1. Run: persona-$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh"
echo "2. Review pending work items"
echo "3. Start with the first work item"
echo ""

# Signal that work is ready for next persona
echo "$NEXT_PERSONA" > /tmp/persona-work-ready

echo -e "${GREEN}✓ Work queue signaled for $NEXT_PERSONA${NC}"
echo ""
echo "The work queue monitor will prepare the first executable task."
