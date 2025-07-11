#!/bin/bash
# QA Persona Initialization Script - ENHANCED for pure event sourcing
# Hook-compatible version

# Colors for output (only if running in terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    BLUE=''
    RED=''
    NC=''
fi

# Determine if running from hook context
HOOK_CONTEXT=""
if [ -n "$HOOK_TYPE" ] || [ -n "$JSON_INPUT" ]; then
    HOOK_CONTEXT="true"
fi

# Log initialization with transition complete event
es-journal-log.sh "QA:INIT" "Starting QA persona"
es-journal-log.sh "TRANSITION:COMPLETED" "QA persona active"

# Safety check
SAFETY_STATUS=$(es-journal-query.sh safety-check QA)
INIT_COUNT=$(echo "$SAFETY_STATUS" | grep -o "Iterations: [0-9]*" | cut -d' ' -f2)

if [ "$INIT_COUNT" -gt 10 ]; then
    if [ -n "$HOOK_CONTEXT" ]; then
        es-journal-log.sh "SAFETY:LIMIT" "QA exceeded initialization limit: $INIT_COUNT"
        echo "ERROR: Safety limit exceeded - too many QA initializations" >&2
        exit 1
    else
        echo -e "${RED}Safety limit exceeded${NC}"
        es-journal-log.sh "SAFETY:LIMIT" "QA exceeded safe iteration count"
        exit 1
    fi
fi

# Check for pending work
PENDING_WORK=$(es-journal-query.sh pending-work QA)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] QA: //')
    
    if [ -n "$HOOK_CONTEXT" ]; then
        # Hook context - minimal output
        es-journal-log.sh "QA:CONTEXT" "Initialized with $PENDING_COUNT pending test items"
        
        # Prepare the first work item for execution
        es-work-tracker.sh prepare QA >/dev/null 2>&1
        
        echo "QA initialized with $PENDING_COUNT pending test items. First task: $FIRST_WORK"
        exit 0
    else
        # Interactive context - full output
        echo -e "${GREEN}Found $PENDING_COUNT pending work items:${NC}"
        echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] QA: /    /'
        echo ""
    fi
else
    FIRST_WORK=""
    if [ -n "$HOOK_CONTEXT" ]; then
        echo "QA initialized with no pending work items"
        exit 0
    fi
fi

# Rest of the script only runs in interactive mode
if [ -z "$HOOK_CONTEXT" ]; then
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
        echo ""
    else
        echo -e "${YELLOW}No testing strategy document found${NC}"
    fi

    # Check current branch and PR status
    echo -e "${YELLOW}Checking test environment...${NC}"
    if [ -d .git ]; then
        CURRENT_BRANCH=$(git branch --show-current)
        echo "Current branch: $CURRENT_BRANCH"
        
        # Check for PR
        PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
        if [ -n "$PR_NUMBER" ]; then
            echo "PR #$PR_NUMBER found for this branch"
        else
            echo "No PR found for current branch"
        fi
    fi
    echo ""

    # Check for test frameworks
    echo -e "${YELLOW}Checking test frameworks...${NC}"
    if [ -f "package.json" ]; then
        echo "Node.js project detected"
        if grep -q '"test"' package.json; then
            echo "  Test script found in package.json"
        fi
    elif [ -f "Cargo.toml" ]; then
        echo "Rust project detected"
        echo "  cargo test available"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        echo "Python project detected"
        if command -v pytest >/dev/null 2>&1; then
            echo "  pytest available"
        fi
    elif [ -f "go.mod" ]; then
        echo "Go project detected"
        echo "  go test available"
    fi
    echo ""

    # Check for running services (for integration testing)
    echo -e "${YELLOW}Checking for running services...${NC}"
    if pgrep -f "cargo run\|npm start\|python.*server\|go run" >/dev/null 2>&1; then
        echo -e "${GREEN}Backend service appears to be running${NC}"
    else
        echo -e "${YELLOW}No backend service detected - may need to start for integration tests${NC}"
    fi
    echo ""

    # Display work instructions
    echo -e "${BLUE}=== QA Work Instructions ===${NC}"
    echo ""

    if [ $PENDING_COUNT -gt 0 ]; then
        echo "You have $PENDING_COUNT pending test items. Your immediate task:"
        echo ""
        echo -e "${GREEN}→ $FIRST_WORK${NC}"
        echo ""
        
        # Provide specific guidance based on the first task
        if [[ "$FIRST_WORK" == *"Pull branch"* ]]; then
            echo "Action plan:"
            echo "1. Start this work item:"
            echo "   es-journal-log.sh 'WORK:STARTED' 'QA: $FIRST_WORK'"
            echo ""
            echo "2. Pull the branch (if not already done):"
            echo "   git pull origin $CURRENT_BRANCH"
            echo ""
            echo "3. Mark complete:"
            echo "   es-journal-log.sh 'WORK:COMPLETED' 'QA: $FIRST_WORK'"
        elif [[ "$FIRST_WORK" == *"unit test"* ]]; then
            echo "Action plan:"
            echo "1. Start: es-journal-log.sh 'WORK:STARTED' 'QA: $FIRST_WORK'"
            echo "2. Run unit tests and log results"
            echo "3. Complete: es-journal-log.sh 'WORK:COMPLETED' 'QA: $FIRST_WORK'"
        elif [[ "$FIRST_WORK" == *"integration"* ]]; then
            echo "Action plan:"
            echo "1. Start: es-journal-log.sh 'WORK:STARTED' 'QA: $FIRST_WORK'"
            echo "2. Ensure backend services are running"
            echo "3. Run integration tests against REAL services"
            echo "4. Complete: es-journal-log.sh 'WORK:COMPLETED' 'QA: $FIRST_WORK'"
        else
            echo "Action plan:"
            echo "1. Start: es-journal-log.sh 'WORK:STARTED' 'QA: $FIRST_WORK'"
            echo "2. Execute the testing task"
            echo "3. Log results using appropriate tags:"
            echo "   es-journal-log.sh 'QA:PASSED' 'Test description'"
            echo "   es-journal-log.sh 'QA:FAILED' 'Failed test description'"
            echo "   es-journal-log.sh 'QA:ISSUE' 'Issue description'"
            echo "4. Complete: es-journal-log.sh 'WORK:COMPLETED' 'QA: $FIRST_WORK'"
        fi
        
        echo ""
        echo "5. Continue with remaining test items"
        echo "6. Run persona-qa-handoff.sh when all testing complete"
    else
        echo "No pending test items found. Options:"
        echo "1. Check for recent handoffs:"
        echo "   es-journal-query.sh handoff-chain"
        echo ""
        echo "2. Check work summary:"
        echo "   es-journal-query.sh work-summary QA"
        echo ""
        echo "3. If testing is complete, run:"
        echo "   persona-qa-handoff.sh"
    fi

    echo ""
    echo -e "${YELLOW}QA Testing Requirements:${NC}"
    echo "• CRITICAL: Use REAL services for integration tests (no mocks)"
    echo "• Test all API endpoints with actual requests"
    echo "• Verify error handling and edge cases"
    echo "• Check performance under realistic load"
    echo "• Document all issues found with QA:ISSUE tag"
    echo ""

    echo -e "${BLUE}QA Commands:${NC}"
    echo "• View pending tests: es-journal-query.sh pending-work QA"
    echo "• Log test pass: es-journal-log.sh 'QA:PASSED' 'description'"
    echo "• Log test fail: es-journal-log.sh 'QA:FAILED' 'description'"
    echo "• Log issue: es-journal-log.sh 'QA:ISSUE' 'description'"
    echo "• Check progress: es-journal-query.sh work-summary QA"
    echo ""

    # Display protocol if needed
    if [ $PENDING_COUNT -eq 0 ] || [ "$1" = "--show-protocol" ]; then
        echo -e "${BLUE}=== QA PROTOCOL ===${NC}"
        echo ""
        cat ~/.claude/personas/QA-PROTOCOL.md
    fi
fi

# Log context
es-journal-log.sh "QA:CONTEXT" "Initialized with $PENDING_COUNT pending test items"
