#!/bin/bash
# QA Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing QA Persona ===${NC}"
echo ""

# Log initialization
journal-log "QA:INIT" "Starting QA persona"

# Safety check
SAFETY_STATUS=$(journal-query safety-check QA)
echo "Safety Status: $SAFETY_STATUS"

if echo "$SAFETY_STATUS" | grep -q "WARNING: High iteration count"; then
    echo -e "${RED}Safety limit exceeded${NC}"
    journal-log "SAFETY:LIMIT" "QA exceeded safe iteration count"
    exit 1
fi

if echo "$SAFETY_STATUS" | grep -q "WARNING: No recent progress"; then
    echo -e "${YELLOW}Warning: No recent progress detected${NC}"
    echo "Check for blocking issues or environment problems"
fi
echo ""

# Check for pending work
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_WORK=$(journal-query pending-work QA)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    echo -e "${GREEN}Found $PENDING_COUNT pending work items:${NC}"
    echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] QA: /    /'
    echo ""
    
    # Get first work item
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] QA: //')
else
    echo "No pending work items found."
    FIRST_WORK=""
fi

# Check for handoff document
if [ -f "HANDOFF_TO_QA.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    grep -E "^##|^- " HANDOFF_TO_QA.md | head -15
    echo ""
fi

# Load testing strategy
echo -e "${YELLOW}Loading testing strategy...${NC}"
if [ -f "TESTING_STRATEGY.md" ]; then
    echo -e "${GREEN}Testing strategy found${NC}"
    grep -E "^##|^###" TESTING_STRATEGY.md | head -10
else
    echo -e "${YELLOW}No testing strategy document found${NC}"
fi
echo ""

# Check recent test results
RECENT_TESTS=$(journal-query recent-context QA | grep -E "(PASSED|FAILED)" | tail -5)
if [ -n "$RECENT_TESTS" ]; then
    echo -e "${YELLOW}Recent test results:${NC}"
    echo "$RECENT_TESTS" | sed 's/.*\[\(QA:.*\)\] /[\1] /'
    echo ""
fi

# Check project state
echo -e "${YELLOW}Checking project state...${NC}"
if [ -d .git ]; then
    echo "Current branch: $(git branch --show-current)"
    echo "Available branches:"
    git branch -a | grep -E "(feat/|fix/)" | head -5
else
    echo "No git repository found"
fi
echo ""

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
SERVICE_CHECK=false

# Common ports to check
for port in 8080 3000 5000 8000; do
    if lsof -i :$port >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Service running on port $port"
        SERVICE_CHECK=true
    fi
done

if [ "$SERVICE_CHECK" = false ]; then
    echo -e "${RED}⚠ No services detected on common ports${NC}"
    echo "Remember: Integration tests must use REAL services!"
fi
echo ""

# Log context
journal-log "QA:CONTEXT" "Initialized with $PENDING_COUNT pending test items"

# Display work instructions
echo -e "${BLUE}=== QA Work Instructions ===${NC}"
echo ""

if [ $PENDING_COUNT -gt 0 ]; then
    echo "You have $PENDING_COUNT test items. Your immediate task:"
    echo ""
    echo -e "${GREEN}→ $FIRST_WORK${NC}"
    echo ""
    echo "Action plan:"
    echo "1. Start this test:"
    echo "   journal-log 'WORK:STARTED' 'QA: $FIRST_WORK'"
    echo ""
    echo "2. Execute the test"
    echo ""
    echo "3. Log result:"
    echo "   journal-log 'QA:PASSED' 'Test description' OR"
    echo "   journal-log 'QA:FAILED' 'Test description - reason'"
    echo ""
    echo "4. Complete the work item:"
    echo "   journal-log 'WORK:COMPLETED' 'QA: $FIRST_WORK'"
    echo ""
    echo "5. Continue with next items"
    echo ""
    echo "6. When all testing done:"
    echo "   /home/devuser/.claude/personas/qa/qa-handoff.sh"
else
    echo "No pending work. Options:"
    echo "1. Check recent handoffs:"
    echo "   journal-query handoff-chain"
    echo ""
    echo "2. Run /home/devuser/.claude/personas/qa/qa-handoff.sh if testing is complete"
fi

echo ""
echo -e "${RED}CRITICAL: Test Against REAL Services${NC}"
echo "• Start actual backend services"
echo "• Use real databases, not mocks"
echo "• Test actual API endpoints"
echo "• NO mocking in integration tests"
echo ""

echo -e "${BLUE}Testing Commands:${NC}"
echo "• View work: journal-query pending-work QA"
echo "• Track item: work-tracker '<test-pattern>'"
echo "• Check all: journal-query work-summary QA"
echo "• Get context: get-context-window QA"
echo ""

# Display protocol if needed
if [ $PENDING_COUNT -eq 0 ] || [ "$1" = "--show-protocol" ]; then
    echo -e "${BLUE}=== QA PROTOCOL ===${NC}"
    echo ""
    cat ~/.claude/personas/qa/QA-PROTOCOL.md
fi
