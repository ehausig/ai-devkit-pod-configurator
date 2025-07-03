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

# Safety check
SAFETY_STATUS=$(journal-query safety-check MERGER)
echo "Safety Status: $SAFETY_STATUS"

if echo "$SAFETY_STATUS" | grep -q "WARNING: High iteration count"; then
    echo -e "${RED}Safety limit exceeded${NC}"
    journal-log "SAFETY:LIMIT" "MERGER exceeded safe iteration count"
    exit 1
fi
echo ""

# Check for pending work
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_WORK=$(journal-query pending-work MERGER)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    echo -e "${GREEN}Found $PENDING_COUNT merge tasks:${NC}"
    echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] MERGER: /    /'
    echo ""
    
    # Get first work item
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] MERGER: //')
else
    echo "No pending merge tasks found."
    FIRST_WORK=""
fi

# Check for handoff document
if [ -f "HANDOFF_TO_MERGER.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    grep -E "^##|^- " HANDOFF_TO_MERGER.md | head -15
    echo ""
fi

# Check current branch
echo -e "${YELLOW}Checking repository state...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${YELLOW}⚠${NC} Not on main branch. Will need to switch for merge."
fi

# Check for approved PRs
echo -e "${YELLOW}Checking for approved PRs...${NC}"
if command -v gh >/dev/null 2>&1; then
    APPROVED_PRS=$(gh pr list --json number,title,branch,reviews,mergeable,statusCheckRollup 2>/dev/null | \
        jq -r '.[] | select(.reviews[] | select(.state == "APPROVED")) | "PR #\(.number): \(.title) (\(.branch)) - Checks: \(.statusCheckRollup | length)"')
    
    if [ -n "$APPROVED_PRS" ]; then
        echo -e "${GREEN}Approved PRs ready for merge:${NC}"
        echo "$APPROVED_PRS"
        
        # Get first PR details
        PR_NUMBER=$(echo "$APPROVED_PRS" | head -1 | grep -o '#[0-9]*' | tr -d '#')
        PR_BRANCH=$(gh pr list --json number,branch --jq ".[] | select(.number == $PR_NUMBER) | .branch" 2>/dev/null)
    else
        echo "No approved PRs found"
        PR_NUMBER=""
        PR_BRANCH=""
    fi
else
    echo "GitHub CLI not available - check PRs manually"
    PR_NUMBER=""
    PR_BRANCH=""
fi
echo ""

# Check CI/CD status
if [ -n "$PR_NUMBER" ]; then
    echo -e "${YELLOW}Checking CI/CD status for PR #$PR_NUMBER...${NC}"
    CI_STATUS=$(gh pr checks $PR_NUMBER 2>/dev/null | tail -5)
    if [ -n "$CI_STATUS" ]; then
        echo "$CI_STATUS"
    else
        echo "Unable to check CI/CD status"
    fi
    echo ""
fi

# Check recent merges
echo -e "${YELLOW}Recent merge history:${NC}"
git log --oneline --merges -5 2>/dev/null | head -5 || echo "No recent merges"
echo ""

# Check for version tags
echo -e "${YELLOW}Recent version tags:${NC}"
git tag --sort=-version:refname | head -5 2>/dev/null || echo "No version tags found"
echo ""

# Check if CHANGELOG exists
echo -e "${YELLOW}Checking documentation...${NC}"
if [ -f "CHANGELOG.md" ]; then
    echo -e "${GREEN}✓${NC} CHANGELOG.md exists"
    echo "Last entry:"
    grep -A 3 "^##" CHANGELOG.md | head -4
else
    echo -e "${YELLOW}⚠${NC} No CHANGELOG.md found"
fi
echo ""

# Log context
journal-log "MERGER:CONTEXT" "Initialized with $PENDING_COUNT merge tasks"

# Display work instructions
echo -e "${BLUE}=== MERGER Work Instructions ===${NC}"
echo ""

if [ $PENDING_COUNT -gt 0 ]; then
    echo "You have $PENDING_COUNT merge tasks. Your immediate task:"
    echo ""
    echo -e "${GREEN}→ $FIRST_WORK${NC}"
    echo ""
    
    # Provide specific instructions based on task
    if [[ "$FIRST_WORK" == *"CI/CD"* ]]; then
        echo "Action plan:"
        echo "1. Mark started: journal-log 'WORK:STARTED' 'MERGER: $FIRST_WORK'"
        echo "2. Check CI/CD status:"
        if [ -n "$PR_NUMBER" ]; then
            echo "   gh pr checks $PR_NUMBER"
        else
            echo "   # Check your CI/CD dashboard"
        fi
        echo "3. Wait for all checks to pass"
        echo "4. Mark complete: journal-log 'WORK:COMPLETED' 'MERGER: $FIRST_WORK'"
    elif [[ "$FIRST_WORK" == *"Merge PR"* ]]; then
        echo "Action plan:"
        echo "1. Mark started: journal-log 'WORK:STARTED' 'MERGER: $FIRST_WORK'"
        echo "2. Switch to main branch:"
        echo "   git checkout main"
        echo "   git pull origin main"
        echo "3. Merge the PR:"
        if [ -n "$PR_NUMBER" ]; then
            echo "   gh pr merge $PR_NUMBER --merge --no-squash --delete-branch"
        else
            echo "   git merge --no-ff $PR_BRANCH"
        fi
        echo "4. Mark complete: journal-log 'WORK:COMPLETED' 'MERGER: $FIRST_WORK'"
        echo "5. Log merge: journal-log 'MERGER:MERGED' 'Merged PR #$PR_NUMBER'"
    else
        echo "Action plan:"
        echo "1. Mark started: journal-log 'WORK:STARTED' 'MERGER: $FIRST_WORK'"
        echo "2. Complete the task"
        echo "3. Mark complete: journal-log 'WORK:COMPLETED' 'MERGER: $FIRST_WORK'"
    fi
    echo ""
    echo "4. Continue with remaining tasks"
    echo "5. Run /home/devuser/.claude/personas/merger/merger-handoff.sh when all complete"
else
    echo "No pending merge tasks. Options:"
    echo "1. Check for approved PRs:"
    echo "   gh pr list --search 'review:approved'"
    echo ""
    echo "2. Check recent handoffs:"
    echo "   journal-query handoff-chain"
    echo ""
    echo "3. If merge cycle is complete:"
    echo "   /home/devuser/.claude/personas/merger/merger-handoff.sh"
fi

echo ""
echo -e "${BLUE}Merge Checklist:${NC}"
echo "□ All CI/CD checks passing"
echo "□ Tests run successfully"
echo "□ No merge conflicts"
echo "□ CHANGELOG updated"
echo "□ Version bumped (if needed)"
echo "□ Documentation updated"
echo ""

echo -e "${BLUE}Merge Commands:${NC}"
echo "• View tasks: journal-query pending-work MERGER"
echo "• Check PR: gh pr checks $PR_NUMBER"
echo "• Merge PR: gh pr merge $PR_NUMBER --merge --no-squash"
echo "• Tag release: git tag -a v1.0.0 -m 'Release version 1.0.0'"
echo "• Check progress: journal-query work-summary MERGER"
echo ""

echo -e "${YELLOW}Remember:${NC}"
echo "• Use --no-ff for clear merge history"
echo "• Update CHANGELOG before tagging"
echo "• Delete feature branches after merge"
echo ""

# Display protocol if needed
if [ $PENDING_COUNT -eq 0 ] || [ "$1" = "--show-protocol" ]; then
    echo -e "${BLUE}=== MERGER PROTOCOL ===${NC}"
    echo ""
    cat ~/.claude/personas/merger/MERGER-PROTOCOL.md
fi
