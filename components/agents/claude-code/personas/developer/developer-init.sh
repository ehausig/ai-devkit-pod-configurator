#!/bin/bash
# DEVELOPER Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing DEVELOPER Persona ===${NC}"
echo ""

# Log initialization
journal-log "DEVELOPER:INIT" "Starting DEVELOPER persona"

# Safety check
SAFETY_STATUS=$(journal-query safety-check DEVELOPER)
echo "Safety Status: $SAFETY_STATUS"

# Check if safety limits exceeded
if echo "$SAFETY_STATUS" | grep -q "WARNING: High iteration count"; then
    echo -e "${RED}Safety limit exceeded${NC}"
    journal-log "SAFETY:LIMIT" "DEVELOPER exceeded safe iteration count"
    exit 1
fi

if echo "$SAFETY_STATUS" | grep -q "WARNING: No recent progress"; then
    echo -e "${YELLOW}Warning: No recent progress detected${NC}"
    echo "Please check for blocking issues or incomplete work"
fi
echo ""

# Check for pending work
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_WORK=$(journal-query pending-work DEVELOPER)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    echo -e "${GREEN}Found $PENDING_COUNT pending work items:${NC}"
    echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] DEVELOPER: /    /'
    echo ""
    
    # Store first work item for immediate action
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] DEVELOPER: //')
else
    echo "No pending work items found."
    FIRST_WORK=""
fi

# Check for handoff document
if [ -f "HANDOFF_TO_DEVELOPER.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    grep -E "^##|^- " HANDOFF_TO_DEVELOPER.md | head -15
    echo ""
fi

# Get architectural context
echo -e "${YELLOW}Loading architectural context...${NC}"
ARCH_DECISIONS=$(journal-query decisions ARCHITECT 5)
if [ -n "$ARCH_DECISIONS" ]; then
    echo -e "${GREEN}Key architectural decisions:${NC}"
    echo "$ARCH_DECISIONS" | sed 's/.*\[.*:DECISION\] /- /'
    echo ""
fi

# Check for unresolved issues
ERRORS=$(journal-query errors DEVELOPER 5)
if [ -n "$ERRORS" ]; then
    echo -e "${RED}Recent issues:${NC}"
    echo "$ERRORS" | sed 's/.*\[\(.*\)\] /[\1] /'
    echo ""
fi

# Check current project state
echo -e "${YELLOW}Checking project state...${NC}"
if [ -d .git ]; then
    CURRENT_BRANCH=$(git branch --show-current)
    echo "Current branch: $CURRENT_BRANCH"
    
    # Check for feature branches
    echo "Feature branches:"
    git branch -a | grep "feat/" || echo "  No feature branches found"
    
    echo "Repository status:"
    git status --short | head -5
else
    echo "No git repository found"
fi
echo ""

# Check for existing code structure
echo -e "${YELLOW}Checking code structure...${NC}"
if [ -d "src" ] || [ -d "backend" ] || [ -d "frontend" ]; then
    echo "Found directories:"
    ls -la | grep "^d" | grep -E "(src|backend|frontend|tests)" || echo "  No standard directories"
else
    echo "No implementation directories found yet"
fi

# Check test framework
if [ -f "package.json" ] || [ -f "Cargo.toml" ] || [ -f "requirements.txt" ] || [ -f "go.mod" ]; then
    echo ""
    echo -e "${YELLOW}Project type detected:${NC}"
    [ -f "package.json" ] && echo "  Node.js/JavaScript project"
    [ -f "Cargo.toml" ] && echo "  Rust project"
    [ -f "requirements.txt" ] && echo "  Python project"
    [ -f "go.mod" ] && echo "  Go project"
    
    if [ -d "tests" ] || [ -d "test" ] || [ -d "__tests__" ]; then
        echo -e "${GREEN}  Test directory found${NC}"
    else
        echo -e "${YELLOW}  No test directory - remember TDD!${NC}"
    fi
fi
echo ""

# Log context
journal-log "DEVELOPER:CONTEXT" "Initialized with $PENDING_COUNT pending work items"

# Display work instructions
echo -e "${BLUE}=== DEVELOPER Work Instructions ===${NC}"
echo ""

if [ $PENDING_COUNT -gt 0 ]; then
    echo "You have $PENDING_COUNT pending work items. Your immediate task:"
    echo ""
    echo -e "${GREEN}→ $FIRST_WORK${NC}"
    echo ""
    echo "Action plan:"
    echo "1. Start this work item:"
    echo "   journal-log 'WORK:STARTED' 'DEVELOPER: $FIRST_WORK'"
    echo ""
    echo "2. Follow TDD approach:"
    echo "   - Write failing test first"
    echo "   - Implement minimum code to pass"
    echo "   - Refactor if needed"
    echo ""
    echo "3. When complete:"
    echo "   journal-log 'WORK:COMPLETED' 'DEVELOPER: $FIRST_WORK'"
    echo ""
    echo "4. Check next work item:"
    echo "   journal-query pending-work DEVELOPER"
    echo ""
    echo "5. When all work is done:"
    echo "   /home/devuser/.claude/personas/developer/developer-handoff.sh"
else
    echo "No pending work found. Options:"
    echo "1. Check for recent handoffs:"
    echo "   journal-query handoff-chain"
    echo ""
    echo "2. Check work summary:"
    echo "   journal-query work-summary DEVELOPER"
    echo ""
    echo "3. If implementation is complete, run:"
    echo "   /home/devuser/.claude/personas/developer/developer-handoff.sh"
fi

echo ""
echo -e "${YELLOW}TDD Workflow Reminder:${NC}"
echo "1. Write test: Create test file in tests/"
echo "2. Run test: Verify it fails"
echo "3. Implement: Write minimum code"
echo "4. Run test: Verify it passes"
echo "5. Refactor: Improve code quality"
echo "6. Commit: git commit with clear message"
echo ""

# Create work tracking alias for convenience
echo -e "${BLUE}Helpful commands:${NC}"
echo "• View pending work: journal-query pending-work DEVELOPER"
echo "• Track work item: work-tracker '<work-pattern>'"
echo "• Check progress: journal-query work-summary DEVELOPER"
echo "• View context: get-context-window DEVELOPER"
echo ""

# Display the protocol if first time or explicitly requested
if [ $PENDING_COUNT -eq 0 ] || [ "$1" = "--show-protocol" ]; then
    echo -e "${BLUE}=== DEVELOPER PROTOCOL ===${NC}"
    echo ""
    cat ~/.claude/personas/developer/DEVELOPER-PROTOCOL.md
fi
