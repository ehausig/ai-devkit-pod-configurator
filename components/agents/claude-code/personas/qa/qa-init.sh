#!/bin/bash
# QA Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing QA Persona ===${NC}"
echo ""

# Log initialization
journal-log "QA:INIT" "Starting QA persona"

# Check for pending handoffs
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING=$(grep "HANDOFF.*QA" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$PENDING" ]; then
    echo -e "${GREEN}Found pending handoffs:${NC}"
    echo "$PENDING"
    echo ""
fi

# Check for handoff file
if [ -f "HANDOFF_TO_QA.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    head -20 HANDOFF_TO_QA.md
    echo "..."
    echo ""
fi

# Load testing strategy
echo -e "${YELLOW}Loading testing strategy...${NC}"
if [ -f "TESTING_STRATEGY.md" ]; then
    echo -e "${GREEN}Testing strategy found${NC}"
    grep -E "^##|^- " TESTING_STRATEGY.md | head -10
    echo ""
else
    echo -e "${YELLOW}No testing strategy document found${NC}"
fi

# Check recent QA activities
RECENT_QA=$(grep "\[QA:" ~/workspace/JOURNAL.md | tail -10)
if [ -n "$RECENT_QA" ]; then
    echo -e "${GREEN}Recent QA activities:${NC}"
    echo "$RECENT_QA" | tail -5
    echo ""
fi

# Check for previous test failures
FAILURES=$(grep "QA:FAILED" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$FAILURES" ]; then
    echo -e "${YELLOW}Previous test failures:${NC}"
    echo "$FAILURES" | sed 's/.*\[QA:FAILED\] /- /'
    echo ""
fi

# Check project state
echo -e "${YELLOW}Checking project state...${NC}"
if [ -d .git ]; then
    echo "Current branch: $(git branch --show-current)"
    echo "Available branches:"
    git branch -a | grep -E "(feat/|fix/)" | head -10
    echo ""
fi

# Check for test directories
echo -e "${YELLOW}Checking test structure...${NC}"
for dir in tests test spec __tests__; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}Found test directory:${NC} $dir"
        find "$dir" -type f -name "*test*" -o -name "*spec*" | head -5
    fi
done
echo ""

# Check for running services
echo -e "${YELLOW}Checking for running services...${NC}"
if lsof -i :8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Service running on port 8080"
else
    echo -e "${YELLOW}⚠${NC} No service on port 8080"
fi

if lsof -i :3000 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Service running on port 3000"
else
    echo -e "${YELLOW}⚠${NC} No service on port 3000"
fi
echo ""

# Log context understanding
journal-log "QA:CONTEXT" "Initialized with testing context"

# Display next steps
echo -e "${BLUE}=== QA Persona Ready ===${NC}"
echo ""
echo "Next steps:"
echo "1. Review TESTING_STRATEGY.md"
echo "2. Pull branch mentioned in handoff"
echo "3. Start backend/frontend services"
echo "4. Run existing test suites"
echo "5. Test against REAL services (no mocks!)"
echo "6. Perform user simulation testing"
echo "7. Document any bugs found"
echo "8. Run qa-handoff.sh when complete"
echo ""

# Create prompt reminder
echo -e "${YELLOW}Remember to log all testing:${NC}"
echo 'journal-log "QA:CONTEXT" "Testing: [what]"'
echo 'journal-log "QA:PASSED" "Test passed: [test]"'
echo 'journal-log "QA:FAILED" "Test failed: [test] - [reason]"'
echo 'journal-log "QA:ISSUE" "Bug found: [description]"'
echo ""

# Display the full protocol inline
echo -e "${BLUE}=== QA PROTOCOL ===${NC}"
echo ""
cat ~/.claude/personas/qa/QA-PROTOCOL.md
echo ""
echo -e "${YELLOW}The above protocol defines your responsibilities as QA.${NC}"
