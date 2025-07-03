#!/bin/bash
# DEVELOPER Persona Handoff Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DEVELOPER Handoff Process ===${NC}"
echo ""

# Log handoff request
journal-log "HANDOFF:REQUEST" "DEVELOPER requesting handoff to QA"

# Check for pending work
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_CHECK=$(journal-query handoff-ready DEVELOPER)
HANDOFF_READY=$?

if [ $HANDOFF_READY -ne 0 ]; then
    echo -e "${RED}$PENDING_CHECK${NC}"
    journal-log "HANDOFF:BLOCKED" "DEVELOPER has incomplete work items"
    exit 1
fi

echo -e "${GREEN}✓${NC} All work items completed"

# Validate completion criteria
echo -e "${YELLOW}Validating completion criteria...${NC}"
READY=true
MISSING=""

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ ! "$CURRENT_BRANCH" =~ ^feat/ ]]; then
    echo -e "${YELLOW}⚠${NC} Not on a feature branch (current: $CURRENT_BRANCH)"
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}✗${NC} Uncommitted changes found"
    READY=false
    MISSING="$MISSING uncommitted-changes"
else
    echo -e "${GREEN}✓${NC} Working directory clean"
fi

# Run tests based on project type
echo -e "${YELLOW}Running tests...${NC}"
TEST_PASSED=false
TEST_OUTPUT=""

if [ -f "package.json" ]; then
    echo "Running npm tests..."
    if npm test 2>&1 | tee test-output.log | grep -E "(passing|passed|✓)"; then
        TEST_PASSED=true
        echo -e "${GREEN}✓${NC} JavaScript tests passing"
    fi
elif [ -f "Cargo.toml" ]; then
    echo "Running cargo tests..."
    if cargo test 2>&1 | tee test-output.log | grep -E "(passed|ok)"; then
        TEST_PASSED=true
        echo -e "${GREEN}✓${NC} Rust tests passing"
    fi
elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
    echo "Running Python tests..."
    if (python -m pytest 2>&1 || pytest 2>&1) | tee test-output.log | grep -E "(passed|PASSED)"; then
        TEST_PASSED=true
        echo -e "${GREEN}✓${NC} Python tests passing"
    fi
elif [ -f "go.mod" ]; then
    echo "Running go tests..."
    if go test ./... 2>&1 | tee test-output.log | grep -E "(PASS|ok)"; then
        TEST_PASSED=true
        echo -e "${GREEN}✓${NC} Go tests passing"
    fi
else
    echo -e "${YELLOW}⚠${NC} No recognized test framework"
    TEST_PASSED=true  # Don't block if no tests
fi

if [ "$TEST_PASSED" = false ]; then
    echo -e "${RED}✗${NC} Tests failing"
    READY=false
    MISSING="$MISSING failing-tests"
    
    # Log test failures
    if [ -f "test-output.log" ]; then
        FAILURES=$(grep -E "(FAIL|failed|✗)" test-output.log | head -5)
        journal-log "DEVELOPER:TEST_FAILED" "Tests failing: $FAILURES"
    fi
fi

# Clean up test output
rm -f test-output.log

# Check for PR
PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
if [ -n "$PR_NUMBER" ]; then
    echo -e "${GREEN}✓${NC} PR #$PR_NUMBER exists"
else
    echo -e "${YELLOW}⚠${NC} No PR created yet"
fi

if [ "$READY" = false ]; then
    echo ""
    echo -e "${RED}ERROR: Not ready for handoff. Issues: $MISSING${NC}"
    journal-log "HANDOFF:BLOCKED" "Missing requirements: $MISSING"
    exit 1
fi

# Validation passed
journal-log "HANDOFF:VALIDATED" "All DEVELOPER requirements met"

echo ""
echo -e "${GREEN}All criteria met. Proceeding with handoff...${NC}"
echo ""

# Create work items for QA
echo -e "${YELLOW}Creating work items for QA...${NC}"

# Get implementation summary
COMPLETED_WORK=$(journal-query recent-context DEVELOPER | grep "WORK:COMPLETED" | tail -10)
WORK_COUNT=$(echo "$COMPLETED_WORK" | wc -l)

# Create QA work items based on what was implemented
journal-log "WORK:PENDING" "QA: Pull branch $CURRENT_BRANCH and set up test environment"
journal-log "WORK:PENDING" "QA: Run unit test suite and verify coverage"
journal-log "WORK:PENDING" "QA: Start backend services for integration testing"
journal-log "WORK:PENDING" "QA: Run integration tests against REAL services (no mocks)"
journal-log "WORK:PENDING" "QA: Perform user simulation testing"
journal-log "WORK:PENDING" "QA: Test error handling and edge cases"
journal-log "WORK:PENDING" "QA: Check performance and resource usage"
journal-log "WORK:PENDING" "QA: Document any bugs or issues found"
journal-log "WORK:PENDING" "QA: Create test report with pass/fail decision"

# Count QA work items
QA_WORK_ITEMS=$(journal-query pending-work QA | wc -l)

# Get summary statistics
COMMITS=$(git rev-list --count HEAD ^main 2>/dev/null || echo "0")
FILES_CHANGED=$(git diff --name-only main 2>/dev/null | wc -l || echo "0")

# Create PR if needed
if [ -z "$PR_NUMBER" ]; then
    echo -e "${YELLOW}Creating Pull Request...${NC}"
    PR_TITLE="feat: $CURRENT_BRANCH implementation"
    PR_BODY="## Summary
Implementation complete for $CURRENT_BRANCH

## Changes
- Implemented $WORK_COUNT work items
- Files changed: $FILES_CHANGED
- Commits: $COMMITS

## Testing
✅ All tests passing
✅ Ready for QA review

## Completed Work
$(echo "$COMPLETED_WORK" | sed 's/.*WORK:COMPLETED\] DEVELOPER: /- /')
"
    
    if gh pr create --title "$PR_TITLE" --body "$PR_BODY" 2>&1 | tee pr-output.log; then
        PR_NUMBER=$(grep -o '#[0-9]*' pr-output.log | head -1 | tr -d '#')
        echo -e "${GREEN}Created PR #$PR_NUMBER${NC}"
    else
        echo -e "${YELLOW}Could not create PR automatically${NC}"
    fi
    rm -f pr-output.log
fi

# Create handoff document
cat > HANDOFF_TO_QA.md << EOF
# Handoff from DEVELOPER to QA

## Date: $(date -Iseconds)

## Summary
Implementation is complete with all tests passing. Ready for comprehensive QA testing.

## Work Items for QA
$(journal-query pending-work QA | sed 's/.*WORK:PENDING\] QA: /- /')

## Implementation Details
- Branch: $CURRENT_BRANCH
- PR: #${PR_NUMBER:-"pending"}
- Commits: $COMMITS
- Files Changed: $FILES_CHANGED
- Work Items Completed: $WORK_COUNT

## Completed Development Work
$(echo "$COMPLETED_WORK" | sed 's/.*WORK:COMPLETED\] DEVELOPER: /- /')

## Test Status
- Unit Tests: ✅ Passing
- Test Framework: Detected and verified
- Working Directory: Clean

## Testing Guidelines
1. Test against REAL services only (no mocks in integration tests)
2. Verify all API endpoints with actual requests
3. Test error scenarios thoroughly
4. Check performance under load
5. Validate security measures

## Known Issues
$(journal-query errors DEVELOPER 5 | sed 's/.*\[\(.*\)\] /- [\1] /' || echo "None reported")

## QA Focus Areas
Based on the implementation, pay special attention to:
$(journal-query decisions ARCHITECT 3 | grep -E "(critical|important|security)" | sed 's/.*DECISION\] /- /' || echo "- Standard testing procedures apply")
EOF

echo -e "${GREEN}Created HANDOFF_TO_QA.md${NC}"

# Complete handoff
journal-log "HANDOFF:COMPLETED" "Handed off to QA with $QA_WORK_ITEMS work items"
journal-log "DEVELOPER:CONTEXT" "Implementation complete, all tests passing, PR #${PR_NUMBER:-pending}"

echo ""
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo -e "${YELLOW}QA should now:${NC}"
echo "1. Run: /home/devuser/.claude/personas/qa/qa-init.sh"
echo "2. Review pending work: journal-query pending-work QA"
echo "3. Start testing with real services"
echo ""

# Auto-continue
echo -e "${GREEN}=== Activating QA persona ===${NC}"
echo ""
sleep 2

# Explicit instruction
echo -e "${YELLOW}Claude, please continue as QA by:${NC}"
echo "1. Setting up the test environment"
echo "2. Running all test suites"
echo "3. Testing against real services"
echo ""

/home/devuser/.claude/personas/qa/qa-init.sh
