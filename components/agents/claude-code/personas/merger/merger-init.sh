#!/bin/bash
# MERGER Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing MERGER Persona ===${NC}"
echo ""

# Log initialization
journal-log "MERGER:INIT" "Starting MERGER persona"

# Check for pending handoffs
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING=$(grep "HANDOFF.*MERGER" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$PENDING" ]; then
    echo -e "${GREEN}Found pending handoffs:${NC}"
    echo "$PENDING"
    echo ""
fi

# Check for handoff file
if [ -f "HANDOFF_TO_MERGER.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    head -20 HANDOFF_TO_MERGER.md
    echo "..."
    echo ""
fi

# Check current branch
echo -e "${YELLOW}Checking repository state...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${YELLOW}⚠${NC} Not on main branch. Switching..."
    git checkout main || git checkout master
    git pull origin main || git pull origin master
fi
echo ""

# Check for approved PRs
echo -e "${YELLOW}Checking for approved PRs...${NC}"
if command -v gh >/dev/null 2>&1; then
    APPROVED_PRS=$(gh pr list --json number,title,branch,reviews,mergeable 2>/dev/null | jq -r '.[] | select(.reviews[] | select(.state == "APPROVED")) | "PR #\(.number): \(.title) (\(.branch)) - Mergeable: \(.mergeable)"')
    if [ -n "$APPROVED_PRS" ]; then
        echo -e "${GREEN}Approved PRs ready for merge:${NC}"
        echo "$APPROVED_PRS"
    else
        echo "No approved PRs found"
    fi
else
    echo "GitHub CLI not available - check PRs manually"
fi
echo ""

# Check CI/CD status
echo -e "${YELLOW}Checking CI/CD status...${NC}"
if command -v gh >/dev/null 2>&1 && [ -n "$APPROVED_PRS" ]; then
    PR_NUMBER=$(echo "$APPROVED_PRS" | head -1 | grep -o '#[0-9]*' | tr -d '#')
    if [ -n "$PR_NUMBER" ]; then
        CI_STATUS=$(gh pr checks $PR_NUMBER 2>/dev/null | tail -5)
        echo "CI/CD status for PR #$PR_NUMBER:"
        echo "$CI_STATUS"
    fi
else
    echo "Unable to check CI/CD status automatically"
fi
echo ""

# Check recent merges
echo -e "${YELLOW}Recent merge history:${NC}"
git log --oneline --merges -10 | head -5
echo ""

# Check for existing tags
echo -e "${YELLOW}Recent version tags:${NC}"
git tag --sort=-version:refname | head -5
echo ""

# Load release context
RECENT_RELEASES=$(grep "MERGER:RELEASE" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$RECENT_RELEASES" ]; then
    echo -e "${GREEN}Recent releases:${NC}"
    echo "$RECENT_RELEASES" | sed 's/.*\[MERGER:RELEASE\] /- /'
    echo ""
fi

# Check for CHANGELOG
echo -e "${YELLOW}Checking documentation...${NC}"
if [ -f "CHANGELOG.md" ]; then
    echo -e "${GREEN}✓${NC} CHANGELOG.md exists"
    echo "Last entry:"
    grep -A 3 "^##" CHANGELOG.md | head -4
else
    echo -e "${YELLOW}⚠${NC} No CHANGELOG.md found"
fi
echo ""

# Log context understanding
journal-log "MERGER:CONTEXT" "Initialized with merge context"

# Display next steps
echo -e "${BLUE}=== MERGER Persona Ready ===${NC}"
echo ""
echo "Next steps:"
echo "1. Verify all PR checks pass"
echo "2. Run final integration tests"
echo "3. Merge approved PRs"
echo "4. Update CHANGELOG.md"
echo "5. Tag release if appropriate"
echo "6. Clean up merged branches"
echo "7. Run merger-handoff.sh when complete"
echo ""

# Create prompt reminder
echo -e "${YELLOW}Remember to log all actions:${NC}"
echo 'journal-log "MERGER:VALIDATION" "Validating: [what]"'
echo 'journal-log "MERGER:MERGED" "Merged: [branch]"'
echo 'journal-log "MERGER:RELEASE" "Released: [version]"'
echo 'journal-log "MERGER:ISSUE" "Problem: [description]"'
echo ""

# Display the full protocol inline
echo -e "${BLUE}=== MERGER PROTOCOL ===${NC}"
echo ""
cat ~/.claude/personas/merger/MERGER-PROTOCOL.md
echo ""
echo -e "${YELLOW}The above protocol defines your responsibilities as MERGER.${NC}"
