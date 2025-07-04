#!/bin/bash
# REVIEWER Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing REVIEWER Persona ===${NC}"
echo ""

# Log initialization
journal-log.sh "REVIEWER:INIT" "Starting REVIEWER persona"

# Safety check
SAFETY_STATUS=$(journal-query.sh safety-check REVIEWER)
echo "Safety Status: $SAFETY_STATUS"

if echo "$SAFETY_STATUS" | grep -q "WARNING: High iteration count"; then
    echo -e "${RED}Safety limit exceeded${NC}"
    journal-log.sh "SAFETY:LIMIT" "REVIEWER exceeded safe iteration count"
    exit 1
fi
echo ""

# Check for pending work
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_WORK=$(journal-query.sh pending-work REVIEWER)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    echo -e "${GREEN}Found $PENDING_COUNT pending review items:${NC}"
    echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] REVIEWER: /    /'
    echo ""
    
    # Get first work item
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] REVIEWER: //')
else
    echo "No pending review items found."
    FIRST_WORK=""
fi

# Check for handoff document
if [ -f "HANDOFF_TO_REVIEWER.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    grep -E "^##|^- " HANDOFF_TO_REVIEWER.md | head -15
    echo ""
fi

# Setup review directory
echo -e "${YELLOW}Setting up review environment...${NC}"
REVIEW_DIR="$HOME/workspace/reviewer"
mkdir -p "$REVIEW_DIR"
echo "Review directory: $REVIEW_DIR"
echo ""

# Get PR information
echo -e "${YELLOW}Checking for pull requests...${NC}"
if command -v gh >/dev/null 2>&1; then
    OPEN_PRS=$(gh pr list --json number,title,branch,mergeable 2>/dev/null)
    if [ -n "$OPEN_PRS" ] && [ "$OPEN_PRS" != "[]" ]; then
        echo -e "${GREEN}Open pull requests:${NC}"
        echo "$OPEN_PRS" | jq -r '.[] | "PR #\(.number): \(.title) (\(.branch))"'
        
        # Store first PR info
        PR_NUMBER=$(echo "$OPEN_PRS" | jq -r '.[0].number' 2>/dev/null || echo "")
        PR_BRANCH=$(echo "$OPEN_PRS" | jq -r '.[0].branch' 2>/dev/null || echo "")
    else
        echo "No open pull requests found"
        PR_NUMBER=""
        PR_BRANCH=""
    fi
else
    echo "GitHub CLI not available"
    PR_NUMBER=""
    PR_BRANCH=""
fi
echo ""

# Load architectural context
echo -e "${YELLOW}Loading architectural decisions...${NC}"
ARCH_DECISIONS=$(journal-query.sh decisions ARCHITECT 5)
if [ -n "$ARCH_DECISIONS" ]; then
    echo -e "${GREEN}Key architectural decisions to check against:${NC}"
    echo "$ARCH_DECISIONS" | sed 's/.*\[.*:DECISION\] /- /'
    echo ""
fi

# Check code quality standards
echo -e "${YELLOW}Checking project standards...${NC}"
for file in .eslintrc* .prettierrc* .rubocop.yml rustfmt.toml .flake8 pyproject.toml; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}Found:${NC} $file (code style configuration)"
    fi
done
echo ""

# Log context
journal-log "REVIEWER:CONTEXT" "Initialized with $PENDING_COUNT review items"

# Display work instructions
echo -e "${BLUE}=== REVIEWER Work Instructions ===${NC}"
echo ""

if [ $PENDING_COUNT -gt 0 ]; then
    echo "You have $PENDING_COUNT review items. Your immediate task:"
    echo ""
    echo -e "${GREEN}→ $FIRST_WORK${NC}"
    echo ""
    
    # Provide specific instructions based on first task
    if [[ "$FIRST_WORK" == *"Clone PR"* ]]; then
        echo "Action plan:"
        echo "1. Mark work started:"
        echo "   journal-log.sh 'WORK:STARTED' 'REVIEWER: $FIRST_WORK'"
        echo ""
        echo "2. Clone to review directory:"
        if [ -n "$PR_BRANCH" ]; then
            echo "   cd $REVIEW_DIR"
            echo "   git clone ~/workspace/$(basename $(pwd)) $(basename $(pwd))-review"
            echo "   cd $(basename $(pwd))-review"
            echo "   git checkout $PR_BRANCH"
        else
            echo "   # Follow instructions in first work item"
        fi
        echo ""
        echo "3. Mark complete and continue:"
        echo "   journal-log.sh  'WORK:COMPLETED' 'REVIEWER: $FIRST_WORK'"
    else
        echo "Action plan:"
        echo "1. Start work: journal-log.sh  'WORK:STARTED' 'REVIEWER: $FIRST_WORK'"
        echo "2. Perform the review task"
        echo "3. Log findings:"
        echo "   journal-log.sh  'REVIEWER:ISSUE' 'Problem description' (for issues)"
        echo "   journal-log.sh  'REVIEWER:FEEDBACK' 'Suggestion' (for improvements)"
        echo "   journal-log.sh  'REVIEWER:APPROVED' 'Component name' (for approvals)"
        echo "4. Complete: journal-log.sh  'WORK:COMPLETED' 'REVIEWER: $FIRST_WORK'"
    fi
    echo ""
    echo "5. Continue with remaining items"
    echo "6. Run /home/devuser/.claude/personas/reviewer/reviewer-handoff.sh when all complete"
else
    echo "No pending review items. Options:"
    echo "1. Check for recent handoffs:"
    echo "   journal-query.sh  handoff-chain"
    echo ""
    echo "2. If review is complete, run:"
    echo "   /home/devuser/.claude/personas/reviewer/reviewer-handoff.sh"
fi

echo ""
echo -e "${BLUE}Review Checklist:${NC}"
echo "□ Code follows project standards"
echo "□ Architecture matches design docs"
echo "□ Tests are comprehensive"
echo "□ Error handling is robust"
echo "□ No security vulnerabilities"
echo "□ Documentation is complete"
echo ""

echo -e "${BLUE}Review Commands:${NC}"
echo "• View work: journal-query.sh  pending-work REVIEWER"
echo "• Log issue: journal-log.sh  'REVIEWER:ISSUE' 'description'"
echo "• Log feedback: journal-log.sh  'REVIEWER:FEEDBACK' 'suggestion'"
echo "• Approve: journal-log.sh  'REVIEWER:APPROVED' 'component'"
echo "• Check progress: journal-query.sh  work-summary REVIEWER"
echo ""

# Display protocol if needed
if [ $PENDING_COUNT -eq 0 ] || [ "$1" = "--show-protocol" ]; then
    echo -e "${BLUE}=== REVIEWER PROTOCOL ===${NC}"
    echo ""
    cat ~/.claude/personas/reviewer/REVIEWER-PROTOCOL.md
fi
