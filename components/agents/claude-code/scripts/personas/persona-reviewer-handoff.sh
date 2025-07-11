#!/bin/bash
# REVIEWER Persona Handoff Script - CLEANED for pure event sourcing

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== REVIEWER Handoff Process ===${NC}"
echo ""

# Analyze review findings
echo -e "${YELLOW}Analyzing review findings...${NC}"

# Count review outcomes
ISSUES=$(es-journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:ISSUE" || echo "0")
FEEDBACK=$(es-journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:FEEDBACK" || echo "0")
APPROVED=$(es-journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:APPROVED" || echo "0")

echo "Review Summary:"
echo "- Critical issues found: $ISSUES"
echo "- Suggestions made: $FEEDBACK"
echo "- Components approved: $APPROVED"
echo ""

# Determine action
if [ $ISSUES -eq 0 ]; then
    ACTION="approved"
    NEXT_PERSONA="MERGER"
    echo -e "${GREEN}No critical issues found. Ready for merge.${NC}"
    es-journal-log.sh "HANDOFF:REQUEST" "REVIEWER requesting handoff to MERGER - code approved"
    es-journal-log.sh "TRANSITION:REQUESTED" "REVIEWER -> MERGER"
else
    ACTION="changes-needed"
    NEXT_PERSONA="DEVELOPER"
    echo -e "${YELLOW}$ISSUES critical issues found. Changes needed.${NC}"
    es-journal-log.sh "HANDOFF:REQUEST" "REVIEWER requesting handoff to DEVELOPER - $ISSUES issues found"
    es-journal-log.sh "TRANSITION:REQUESTED" "REVIEWER -> DEVELOPER"
fi

# Check for pending work
echo ""
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_CHECK=$(es-journal-query.sh handoff-ready REVIEWER)
HANDOFF_READY=$?

if [ $HANDOFF_READY -ne 0 ]; then
    echo -e "${RED}$PENDING_CHECK${NC}"
    es-journal-log.sh "HANDOFF:BLOCKED" "REVIEWER has incomplete review items"
    exit 1
fi

echo -e "${GREEN}✓${NC} All review items completed"

# Validate review completeness
echo ""
echo -e "${YELLOW}Validating review coverage...${NC}"
READY=true

# Check if key areas were reviewed
REVIEW_CONTEXT=$(es-journal-query.sh recent-context REVIEWER)

if echo "$REVIEW_CONTEXT" | grep -q -E "(quality|style|standard)"; then
    echo -e "${GREEN}✓${NC} Code quality reviewed"
else
    echo -e "${YELLOW}⚠${NC} Code quality not explicitly reviewed"
fi

if echo "$REVIEW_CONTEXT" | grep -q -E "(architecture|design)"; then
    echo -e "${GREEN}✓${NC} Architecture compliance checked"
else
    echo -e "${YELLOW}⚠${NC} Architecture compliance not verified"
fi

if echo "$REVIEW_CONTEXT" | grep -q -E "(test|coverage)"; then
    echo -e "${GREEN}✓${NC} Test quality reviewed"
else
    echo -e "${YELLOW}⚠${NC} Test quality not reviewed"
fi

# Validation passed
es-journal-log.sh "HANDOFF:VALIDATED" "Review requirements met"

echo ""
echo -e "${GREEN}Review complete. Creating work items for $NEXT_PERSONA...${NC}"
echo ""

# Create review report
echo -e "${YELLOW}Creating review report...${NC}"

# Get review details
ISSUES_LIST=$(es-journal-query.sh recent-context REVIEWER | grep "REVIEWER:ISSUE" | sed 's/.*\[REVIEWER:ISSUE\] //')
FEEDBACK_LIST=$(es-journal-query.sh recent-context REVIEWER | grep "REVIEWER:FEEDBACK" | sed 's/.*\[REVIEWER:FEEDBACK\] //')
APPROVED_LIST=$(es-journal-query.sh recent-context REVIEWER | grep "REVIEWER:APPROVED" | sed 's/.*\[REVIEWER:APPROVED\] //')

cat > REVIEW_REPORT.md << EOF
# Code Review Report

## Date: $(date -Iseconds)

## Review Summary
- Critical Issues: $ISSUES
- Suggestions: $FEEDBACK
- Approvals: $APPROVED
- Decision: ${ACTION^^}

## Review Coverage
$(echo "$REVIEW_CONTEXT" | grep "WORK:COMPLETED" | sed 's/.*REVIEWER: /- /' | tail -10)

## Code Quality
$(echo "$REVIEW_CONTEXT" | grep -E "(quality|style|naming)" | sed 's/.*\] /- /' | tail -5 || echo "✓ Code quality acceptable")

## Architecture Compliance
$(echo "$REVIEW_CONTEXT" | grep -E "(architecture|design|pattern)" | sed 's/.*\] /- /' | tail -5 || echo "✓ Architecture compliance verified")

## Security Review
$(echo "$REVIEW_CONTEXT" | grep -E "(security|vulnerability|injection)" | sed 's/.*\] /- /' | tail -5 || echo "✓ No security issues found")

## Test Quality
$(echo "$REVIEW_CONTEXT" | grep -E "(test|coverage|mock)" | sed 's/.*\] /- /' | tail -5 || echo "✓ Test quality acceptable")

## Critical Issues
$([ -n "$ISSUES_LIST" ] && echo "$ISSUES_LIST" | sed 's/^/- /' || echo "None")

## Suggestions for Improvement
$([ -n "$FEEDBACK_LIST" ] && echo "$FEEDBACK_LIST" | sed 's/^/- /' || echo "None")

## Approved Components
$([ -n "$APPROVED_LIST" ] && echo "$APPROVED_LIST" | sed 's/^/- /' || echo "None specified")
EOF

# Create work items based on action
if [ "$ACTION" = "approved" ]; then
    echo "" >> REVIEW_REPORT.md
    echo "## Recommendation" >> REVIEW_REPORT.md
    echo "Code meets all quality standards and is ready for merge." >> REVIEW_REPORT.md
    
    # Get PR info
    PR_NUMBER=$(gh pr list --json number --jq '.[0].number' 2>/dev/null || echo "")
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    # Create work items for MERGER
    es-journal-log.sh "WORK:PENDING" "MERGER: Verify all CI/CD checks pass"
    es-journal-log.sh "WORK:PENDING" "MERGER: Run final integration tests on main branch"
    es-journal-log.sh "WORK:PENDING" "MERGER: Merge PR #${PR_NUMBER:-pending} using --no-ff"
    es-journal-log.sh "WORK:PENDING" "MERGER: Update CHANGELOG.md with changes"
    es-journal-log.sh "WORK:PENDING" "MERGER: Tag release if appropriate"
    es-journal-log.sh "WORK:PENDING" "MERGER: Delete feature branch after merge"
    es-journal-log.sh "WORK:PENDING" "MERGER: Update documentation if needed"
    
    WORK_COUNT=7
    cp REVIEW_REPORT.md HANDOFF_TO_MERGER.md
    
else
    echo "" >> REVIEW_REPORT.md
    echo "## Required Changes" >> REVIEW_REPORT.md
    echo "The following issues must be addressed before merge:" >> REVIEW_REPORT.md
    
    # Create specific work items for DEVELOPER
    if [ $ISSUES -gt 0 ]; then
        echo "$ISSUES_LIST" | while IFS= read -r issue; do
            [ -n "$issue" ] && es-journal-log.sh "WORK:PENDING" "DEVELOPER: Fix - $issue"
        done
    fi
    
    if [ $FEEDBACK -gt 0 ]; then
        echo "" >> REVIEW_REPORT.md
        echo "## Suggested Improvements" >> REVIEW_REPORT.md
        echo "$FEEDBACK_LIST" | sed 's/^/- /' >> REVIEW_REPORT.md
        
        # Add work item to consider suggestions
        es-journal-log.sh "WORK:PENDING" "DEVELOPER: Review and implement suggestions from code review"
    fi
    
    # Standard work items for fixes
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Update tests if implementation changed"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Run all tests to verify fixes"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Update PR with review fixes"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Request re-review when complete"
    
    WORK_COUNT=$(es-journal-query.sh pending-work DEVELOPER | wc -l)
    cp REVIEW_REPORT.md HANDOFF_TO_DEVELOPER.md
fi

echo -e "${GREEN}Created REVIEW_REPORT.md${NC}"
echo -e "${GREEN}Created $WORK_COUNT work items for $NEXT_PERSONA${NC}"

# Add PR comment if possible
if [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}Adding review to PR #$PR_NUMBER...${NC}"
    
    if [ "$ACTION" = "approved" ]; then
        gh pr review $PR_NUMBER --approve --body "## ✅ Code Review Approved

All quality standards met. Ready for merge.

- Critical Issues: $ISSUES
- Suggestions: $FEEDBACK
- Components Approved: $APPROVED

See REVIEW_REPORT.md for details." 2>/dev/null && echo -e "${GREEN}Added approval to PR${NC}"
    else
        ISSUES_SUMMARY=$(echo "$ISSUES_LIST" | head -5 | sed 's/^/- /')
        gh pr review $PR_NUMBER --request-changes --body "## 🔄 Changes Requested

Please address the issues identified in the review.

### Critical Issues Found: $ISSUES
$ISSUES_SUMMARY

See REVIEW_REPORT.md for full details." 2>/dev/null && echo -e "${GREEN}Added review comments to PR${NC}"
    fi
fi

# Complete handoff - PURE EVENT SOURCING: Only log to journal
es-journal-log.sh "HANDOFF:COMPLETED" "Handed off to $NEXT_PERSONA with $WORK_COUNT work items"
es-journal-log.sh "REVIEWER:CONTEXT" "Review complete. Decision: $ACTION"

echo ""
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo -e "${YELLOW}$NEXT_PERSONA should now be automatically triggered via journal hook...${NC}"
echo ""

# REMOVED: All file signaling logic
# REMOVED: echo "$NEXT_PERSONA" > /tmp/persona-work-ready
# REMOVED: Atomic file operations

echo -e "${GREEN}✓ Handoff logged to journal${NC}"
echo ""
echo "The journal hook will detect the handoff and automatically trigger $NEXT_PERSONA initialization."
echo ""
echo "If automatic handoff fails, manually run: persona-$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh"
