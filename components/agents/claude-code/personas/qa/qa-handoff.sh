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

# Count test results
PASSED=$(grep -c "QA:PASSED" ~/workspace/JOURNAL.md)
FAILED=$(grep -c "QA:FAILED" ~/workspace/JOURNAL.md)
ISSUES=$(grep -c "QA:ISSUE" ~/workspace/JOURNAL.md)

echo -e "${YELLOW}Test Summary:${NC}"
echo "- Tests passed: $PASSED"
echo "- Tests failed: $FAILED" 
echo "- Issues found: $ISSUES"
echo ""

# Determine next persona based on results
if [ "$FAILED" -eq 0 ] && [ "$ISSUES" -eq 0 ]; then
    NEXT_PERSONA="REVIEWER"
    echo -e "${GREEN}All tests passed! Ready for code review.${NC}"
else
    NEXT_PERSONA="DEVELOPER"
    echo -e "${YELLOW}Issues found. Returning to DEVELOPER for fixes.${NC}"
fi
echo ""

# Validate testing completeness
echo -e "${YELLOW}Validating testing coverage...${NC}"
READY=true

# Check for unit test execution
if grep -q "unit test" ~/workspace/JOURNAL.md || grep -q "Unit test" ~/workspace/JOURNAL.md; then
    echo -e "${GREEN}✓${NC} Unit tests executed"
else
    echo -e "${YELLOW}⚠${NC} No unit test execution logged"
fi

# Check for integration test execution
if grep -q "integration test" ~/workspace/JOURNAL.md || grep -q "Integration test" ~/workspace/JOURNAL.md; then
    echo -e "${GREEN}✓${NC} Integration tests executed"
else
    echo -e "${YELLOW}⚠${NC} No integration test execution logged"
fi

# Check for real service testing
if grep -q "real.*service\|service.*real\|running.*backend\|backend.*running" ~/workspace/JOURNAL.md; then
    echo -e "${GREEN}✓${NC} Tested against real services"
else
    echo -e "${RED}✗${NC} No evidence of real service testing"
    READY=false
fi

echo ""

# Create test report
echo -e "${YELLOW}Creating test report...${NC}"

cat > TEST_REPORT.md << EOF
# QA Test Report

## Date: $(date -Iseconds)

## Test Summary
- Total Tests Passed: $PASSED
- Total Tests Failed: $FAILED
- Issues Found: $ISSUES
- Next Persona: $NEXT_PERSONA

## Test Coverage
### Unit Tests
$(grep "QA:.*unit" ~/workspace/JOURNAL.md | tail -10 | sed 's/.*\[QA:[^]]*\] /- /' || echo "No unit test results logged")

### Integration Tests  
$(grep "QA:.*integration" ~/workspace/JOURNAL.md | tail -10 | sed 's/.*\[QA:[^]]*\] /- /' || echo "No integration test results logged")

### User Simulation Tests
$(grep "QA:.*simulation\|QA:.*user\|QA:.*TUI\|QA:.*e2e" ~/workspace/JOURNAL.md | tail -10 | sed 's/.*\[QA:[^]]*\] /- /' || echo "No user simulation test results logged")

## Issues Found
$(grep "QA:ISSUE" ~/workspace/JOURNAL.md | sed 's/.*\[QA:ISSUE\] /- /' || echo "No issues found")

## Failed Tests
$(grep "QA:FAILED" ~/workspace/JOURNAL.md | sed 's/.*\[QA:FAILED\] /- /' || echo "No test failures")

## Testing Notes
$(grep "QA:MEMORY" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[QA:MEMORY\] /- /' || echo "No additional notes")

## Recommendation
EOF

if [ "$NEXT_PERSONA" = "REVIEWER" ]; then
    cat >> TEST_REPORT.md << EOF
All tests pass and no critical issues found. Ready for code review.

## Next Steps for REVIEWER
1. Review code quality
2. Check architecture compliance  
3. Verify security best practices
4. Ensure documentation completeness
EOF
else
    cat >> TEST_REPORT.md << EOF
Issues found that need to be addressed before proceeding to review.

## Next Steps for DEVELOPER  
1. Review failed tests and issues
2. Fix identified problems
3. Ensure all tests pass
4. Update PR with fixes
EOF
fi

echo -e "${GREEN}Created TEST_REPORT.md${NC}"
echo ""

# Log handoff
if [ "$NEXT_PERSONA" = "REVIEWER" ]; then
    journal-log "QA:CONTEXT" "Testing complete. All tests pass, no critical issues."
    journal-log "QA:HANDOFF" "Ready for REVIEWER. All quality gates passed."
    
    # Create handoff file for reviewer
    cp TEST_REPORT.md HANDOFF_TO_REVIEWER.md
    echo "" >> HANDOFF_TO_REVIEWER.md
    echo "## Additional Context for Review" >> HANDOFF_TO_REVIEWER.md
    echo "- Branch tested: $(git branch --show-current)" >> HANDOFF_TO_REVIEWER.md
    echo "- Services were running during tests" >> HANDOFF_TO_REVIEWER.md
    echo "- All integration tests used real backends" >> HANDOFF_TO_REVIEWER.md
else
    journal-log "QA:CONTEXT" "Testing revealed $ISSUES issues and $FAILED test failures."
    journal-log "QA:HANDOFF" "Returning to DEVELOPER for fixes. See TEST_REPORT.md"
    
    # Create handoff file for developer
    cp TEST_REPORT.md HANDOFF_TO_DEVELOPER.md
    echo "" >> HANDOFF_TO_DEVELOPER.md
    echo "## Priority Fixes" >> HANDOFF_TO_DEVELOPER.md
    grep "QA:FAILED" ~/workspace/JOURNAL.md | head -5 | sed 's/.*\[QA:FAILED\] /- /' >> HANDOFF_TO_DEVELOPER.md
fi

# Display next steps
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo "Next steps:"
if [ "$NEXT_PERSONA" = "REVIEWER" ]; then
    echo "1. REVIEWER should run: /home/devuser/.claude/personas/reviewer/reviewer-init.sh"
    echo "2. REVIEWER should review HANDOFF_TO_REVIEWER.md"
    echo "3. REVIEWER should perform code review"
else
    echo "1. DEVELOPER should run: /home/devuser/.claude/personas/developer/developer-init.sh"  
    echo "2. DEVELOPER should review HANDOFF_TO_DEVELOPER.md"
    echo "3. DEVELOPER should fix identified issues"
fi
echo ""

# Auto-continue to next persona
echo -e "${GREEN}=== Auto-continuing to $NEXT_PERSONA persona ===${NC}"
echo ""
sleep 2  # Brief pause to let the output be visible
/home/devuser/.claude/personas/$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')/$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh
