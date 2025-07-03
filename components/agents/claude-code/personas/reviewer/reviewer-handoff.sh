#!/bin/bash
# REVIEWER Persona Handoff Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're approving or requesting changes
ACTION="${1:-check}"

echo -e "${BLUE}=== REVIEWER Handoff Process ===${NC}"
echo ""

# Count review findings
ISSUES=$(grep -c "REVIEWER:ISSUE" ~/workspace/JOURNAL.md)
FEEDBACK=$(grep -c "REVIEWER:FEEDBACK" ~/workspace/JOURNAL.md)
APPROVED=$(grep -c "REVIEWER:APPROVED" ~/workspace/JOURNAL.md)

echo -e "${YELLOW}Review Summary:${NC}"
echo "- Issues found: $ISSUES"
echo "- Feedback items: $FEEDBACK"
echo "- Components approved: $APPROVED"
echo ""

# Determine action if not specified
if [ "$ACTION" = "check" ]; then
    if [ "$ISSUES" -eq 0 ]; then
        ACTION="approved"
        echo -e "${GREEN}No critical issues found. Proceeding with approval.${NC}"
    else
        ACTION="changes-needed"
        echo -e "${YELLOW}Issues found. Changes needed.${NC}"
    fi
fi
echo ""

# Create review report
echo -e "${YELLOW}Creating review report...${NC}"

cat > REVIEW_REPORT.md << EOF
# Code Review Report

## Date: $(date -Iseconds)

## Review Summary
- Critical Issues: $ISSUES
- Suggestions: $FEEDBACK  
- Approvals: $APPROVED
- Decision: ${ACTION^^}

## Code Quality
$(grep "REVIEWER:.*quality\|REVIEWER:.*style\|REVIEWER:.*naming" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[REVIEWER:[^]]*\] /- /' || echo "✓ Code quality acceptable")

## Architecture Compliance
$(grep "REVIEWER:.*architecture\|REVIEWER:.*design\|REVIEWER:.*pattern" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[REVIEWER:[^]]*\] /- /' || echo "✓ Architecture compliance verified")

## Security Review
$(grep "REVIEWER:.*security\|REVIEWER:.*vulnerability\|REVIEWER:.*injection" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[REVIEWER:[^]]*\] /- /' || echo "✓ No security issues found")

## Test Quality
$(grep "REVIEWER:.*test\|REVIEWER:.*coverage\|REVIEWER:.*mock" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[REVIEWER:[^]]*\] /- /' || echo "✓ Test quality acceptable")

## Critical Issues
$(grep "REVIEWER:ISSUE" ~/workspace/JOURNAL.md | sed 's/.*\[REVIEWER:ISSUE\] /- /' || echo "None")

## Suggestions for Improvement
$(grep "REVIEWER:FEEDBACK" ~/workspace/JOURNAL.md | sed 's/.*\[REVIEWER:FEEDBACK\] /- /' || echo "None")

## Review Decision: ${ACTION^^}
EOF

if [ "$ACTION" = "approved" ]; then
    cat >> REVIEW_REPORT.md << EOF

Code meets all quality standards and is ready for merge.

## Next Steps for MERGER
1. Verify CI/CD pipeline status
2. Perform final integration testing
3. Merge to main branch
4. Update documentation
5. Create release if appropriate
EOF
    
    # Log approval
    journal-log "REVIEWER:CONTEXT" "Code review complete. All standards met."
    journal-log "REVIEWER:APPROVED" "PR approved for merge"
    journal-log "REVIEWER:HANDOFF" "Ready for MERGER. No blocking issues."
    
    # Create handoff for merger
    cp REVIEW_REPORT.md HANDOFF_TO_MERGER.md
    NEXT_PERSONA="MERGER"
    
else
    cat >> REVIEW_REPORT.md << EOF

Changes are required before this code can be merged.

## Required Changes
$(grep "REVIEWER:ISSUE" ~/workspace/JOURNAL.md | head -10 | sed 's/.*\[REVIEWER:ISSUE\] /1. /')

## Suggested Improvements  
$(grep "REVIEWER:FEEDBACK" ~/workspace/JOURNAL.md | head -10 | sed 's/.*\[REVIEWER:FEEDBACK\] /- /')

## Next Steps for DEVELOPER
1. Address all critical issues
2. Consider implementing suggestions
3. Update tests as needed
4. Push fixes to PR
5. Request re-review
EOF
    
    # Log changes needed
    journal-log "REVIEWER:CONTEXT" "Code review complete. $ISSUES issues need addressing."
    journal-log "REVIEWER:HANDOFF" "Changes requested. Returning to DEVELOPER."
    
    # Create handoff for developer
    cp REVIEW_REPORT.md HANDOFF_TO_DEVELOPER.md
    NEXT_PERSONA="DEVELOPER"
fi

echo -e "${GREEN}Created REVIEW_REPORT.md${NC}"
echo ""

# If we have PR number, add review comment
PR_NUMBER=$(gh pr list --json number --jq '.[0].number' 2>/dev/null)
if [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1; then
    echo -e "${YELLOW}Adding review to PR #$PR_NUMBER...${NC}"
    
    if [ "$ACTION" = "approved" ]; then
        gh pr review $PR_NUMBER --approve --body "## ✅ Code Review Approved

All quality standards met. Ready for merge.

See REVIEW_REPORT.md for details." 2>/dev/null && echo -e "${GREEN}Added approval to PR${NC}"
    else
        gh pr review $PR_NUMBER --request-changes --body "## 🔄 Changes Requested

Please address the issues identified in the review.

### Critical Issues:
$(grep "REVIEWER:ISSUE" ~/workspace/JOURNAL.md | head -5 | sed 's/.*\[REVIEWER:ISSUE\] /- /')

See REVIEW_REPORT.md for full details." 2>/dev/null && echo -e "${GREEN}Added review comments to PR${NC}"
    fi
    echo ""
fi

# Display next steps
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo "Next steps:"
if [ "$NEXT_PERSONA" = "MERGER" ]; then
    echo "1. MERGER should run: /home/devuser/.claude/personas/merger/merger-init.sh"
    echo "2. MERGER should review HANDOFF_TO_MERGER.md"
    echo "3. MERGER should perform final checks and merge"
else
    echo "1. DEVELOPER should run: /home/devuser/.claude/personas/developer/developer-init.sh"
    echo "2. DEVELOPER should review HANDOFF_TO_DEVELOPER.md"
    echo "3. DEVELOPER should address review feedback"
fi
echo ""
echo -e "${YELLOW}To switch persona:${NC}"
echo "Run: /home/devuser/.claude/personas/$NEXT_PERSONA/$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh"
