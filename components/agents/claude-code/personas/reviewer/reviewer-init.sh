#!/bin/bash
# REVIEWER Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing REVIEWER Persona ===${NC}"
echo ""

# Log initialization
journal-log "REVIEWER:INIT" "Starting REVIEWER persona"

# Check for pending handoffs
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING=$(grep "HANDOFF.*REVIEWER" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$PENDING" ]; then
    echo -e "${GREEN}Found pending handoffs:${NC}"
    echo "$PENDING"
    echo ""
fi

# Check for handoff file
if [ -f "HANDOFF_TO_REVIEWER.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    head -20 HANDOFF_TO_REVIEWER.md
    echo "..."
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
        echo ""
    else
        echo "No open pull requests found"
        echo ""
    fi
else
    echo "GitHub CLI not available"
    echo ""
fi

# Load architectural context
echo -e "${YELLOW}Loading architectural decisions...${NC}"
ARCH_DECISIONS=$(grep "ARCHITECT:DECISION" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$ARCH_DECISIONS" ]; then
    echo -e "${GREEN}Key architectural decisions:${NC}"
    echo "$ARCH_DECISIONS" | sed 's/.*\[ARCHITECT:DECISION\] /- /'
    echo ""
fi

# Check previous reviews
PREVIOUS_REVIEWS=$(grep "REVIEWER:FEEDBACK" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$PREVIOUS_REVIEWS" ]; then
    echo -e "${GREEN}Previous review feedback:${NC}"
    echo "$PREVIOUS_REVIEWS" | sed 's/.*\[REVIEWER:FEEDBACK\] /- /'
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

# Log context understanding
journal-log "REVIEWER:CONTEXT" "Initialized with review context"

# Display review checklist
echo -e "${BLUE}=== Review Checklist ===${NC}"
echo ""
echo "Code Quality:"
echo "  □ Follows coding standards"
echo "  □ Clear naming conventions"
echo "  □ Proper error handling"
echo "  □ No code duplication"
echo ""
echo "Architecture:"
echo "  □ Matches design documents"
echo "  □ Proper separation of concerns"
echo "  □ Dependency direction correct"
echo ""
echo "Security:"
echo "  □ Input validation present"
echo "  □ No hardcoded secrets"
echo "  □ SQL injection prevention"
echo ""
echo "Testing:"
echo "  □ Adequate test coverage"
echo "  □ Tests are meaningful"
echo "  □ Integration tests use real services"
echo ""

# Display next steps
echo -e "${BLUE}=== REVIEWER Persona Ready ===${NC}"
echo ""
echo "Next steps:"
echo "1. Clone PR to review directory"
echo "2. Run automated checks (lint, security scan)"
echo "3. Review code systematically"
echo "4. Check architecture compliance"
echo "5. Verify test quality"
echo "6. Document feedback"
echo "7. Run reviewer-handoff.sh when complete"
echo ""

# Create prompt reminder
echo -e "${YELLOW}Remember to log all findings:${NC}"
echo 'journal-log "REVIEWER:CONTEXT" "Reviewing: [what]"'
echo 'journal-log "REVIEWER:ISSUE" "Problem: [description]"'
echo 'journal-log "REVIEWER:FEEDBACK" "Suggestion: [improvement]"'
echo 'journal-log "REVIEWER:APPROVED" "Approved: [component]"'
echo ""

# Display the full protocol inline
echo -e "${BLUE}=== REVIEWER PROTOCOL ===${NC}"
echo ""
cat ~/.claude/personas/reviewer/REVIEWER-PROTOCOL.md
echo ""
echo -e "${YELLOW}The above protocol defines your responsibilities as REVIEWER.${NC}"
