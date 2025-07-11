#!/bin/bash
# MERGER Persona Initialization Script - ENHANCED for pure event sourcing

# Colors for output (only if running in terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
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
es-journal-log.sh "MERGER:INIT" "Starting MERGER persona"
es-journal-log.sh "TRANSITION:COMPLETED" "MERGER persona active"

# Safety check
SAFETY_STATUS=$(es-journal-query.sh safety-check MERGER)
INIT_COUNT=$(echo "$SAFETY_STATUS" | grep -o "Iterations: [0-9]*" | cut -d' ' -f2)

if [ $INIT_COUNT -gt 10 ]; then
    if [ -n "$HOOK_CONTEXT" ]; then
        es-journal-log.sh "SAFETY:LIMIT" "MERGER exceeded initialization limit: $INIT_COUNT"
        echo "ERROR: Safety limit exceeded - too many MERGER initializations" >&2
        exit 1
    else
        echo -e "${RED}Safety limit exceeded${NC}"
        es-journal-log.sh "SAFETY:LIMIT" "MERGER exceeded safe iteration count"
        exit 1
    fi
fi

# Check for pending work
PENDING_WORK=$(es-journal-query.sh pending-work MERGER)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] MERGER: //')
    
    if [ -n "$HOOK_CONTEXT" ]; then
        # Hook context - minimal output
        es-journal-log.sh "MERGER:CONTEXT" "Initialized with $PENDING_COUNT merge tasks"
        
        # Prepare the first work item for execution
        es-work-tracker.sh prepare MERGER >/dev/null 2>&1
        
        echo "MERGER initialized with $PENDING_COUNT merge tasks. First task: $FIRST_WORK"
        exit 0
    else
        # Interactive context - full output
        echo -e "${GREEN}Found $PENDING_COUNT merge tasks:${NC}"
        echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] MERGER: /    /'
        echo ""
    fi
else
    FIRST_WORK=""
    if [ -n "$HOOK_CONTEXT" ]; then
        echo "MERGER initialized with no pending work items"
        exit 0
    fi
fi

# Rest of the script only runs in interactive mode
if [ -z "$HOOK_CONTEXT" ]; then
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
        APPROVED_PRS=$(gh pr list --json number,title,branch,mergeable,statusCheckRollup 2>/dev/null | \
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
        echo "GitHub CLI not available"
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
            echo "1. Mark started: es-journal-log.sh 'WORK:STARTED' 'MERGER: $FIRST_WORK'"
            echo "2. Check CI/CD status:"
            if [ -n "$PR_NUMBER" ]; then
                echo "   gh pr checks $PR_NUMBER"
            else
                echo "   # Check your CI/CD dashboard"
            fi
            echo "3. Wait for all checks to pass"
            echo "4. Mark complete: es-journal-log.sh 'WORK:COMPLETED' 'MERGER: $FIRST_WORK'"
        elif [[ "$FIRST_WORK" == *"Merge PR"* ]]; then
            echo "Action plan:"
            echo "1. Mark started: es-journal-log.sh 'WORK:STARTED' 'MERGER: $FIRST_WORK'"
            echo "2. Switch to main branch:"
            echo "   git checkout main"
            echo "   git pull origin main"
            echo "3. Merge the PR:"
            if [ -n "$PR_NUMBER" ]; then
                echo "   gh pr merge $PR_NUMBER --merge --no-squash --delete-branch"
            else
                echo "   git merge --no-ff $PR_BRANCH"
            fi
            echo "4. Mark complete: es-journal-log.sh 'WORK:COMPLETED' 'MERGER: $FIRST_WORK'"
            echo "5. Log merge: es-journal-log.sh 'MERGER:MERGED' 'Merged PR #$PR_NUMBER'"
        else
            echo "Action plan:"
            echo "1. Mark started: es-journal-log.sh 'WORK:STARTED' 'MERGER: $FIRST_WORK'"
            echo "2. Complete the task"
            echo "3. Mark complete: es-journal-log.sh 'WORK:COMPLETED' 'MERGER: $FIRST_WORK'"
        fi
        echo ""
        echo "4. Continue with remaining tasks"
        echo "5. Run persona-merger-handoff.sh when all complete"
    else
        echo "No pending merge tasks. Options:"
        echo "1. Check for approved PRs:"
        echo "   gh pr list --search 'review:approved'"
        echo ""
        echo "2. Check recent handoffs:"
        echo "   es-journal-query.sh handoff-chain"
        echo ""
        echo "3. If merge cycle is complete:"
        echo "   persona-merger-handoff.sh"
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
    echo "• View tasks: es-journal-query.sh pending-work MERGER"
    echo "• Check PR: gh pr checks $PR_NUMBER"
    echo "• Merge PR: gh pr merge $PR_NUMBER --merge --no-squash"
    echo "• Tag release: git tag -a v1.0.0 -m 'Release version 1.0.0'"
    echo "• Check progress: es-journal-query.sh work-summary MERGER"
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
        cat ~/.claude/personas/MERGER-PROTOCOL.md
    fi
fi

# Log context
es-journal-log.sh "MERGER:CONTEXT" "Initialized with $PENDING_COUNT merge tasks"
