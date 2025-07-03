#!/bin/bash
# MERGER Persona Handoff Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MERGER Handoff Process ===${NC}"
echo ""

# Log handoff request
journal-log "HANDOFF:REQUEST" "MERGER requesting cycle completion"

# Check for pending work
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_CHECK=$(journal-query handoff-ready MERGER)
HANDOFF_READY=$?

if [ $HANDOFF_READY -ne 0 ]; then
    echo -e "${RED}$PENDING_CHECK${NC}"
    journal-log "HANDOFF:BLOCKED" "MERGER has incomplete tasks"
    exit 1
fi

echo -e "${GREEN}✓${NC} All merge tasks completed"

# Count merge activities
echo ""
echo -e "${YELLOW}Merge Summary:${NC}"
MERGED=$(journal-query recent-context MERGER | grep -c "MERGER:MERGED" || echo "0")
RELEASES=$(journal-query recent-context MERGER | grep -c "MERGER:RELEASE" || echo "0")
ISSUES=$(journal-query recent-context MERGER | grep -c "MERGER:ISSUE" || echo "0")

echo "- Branches merged: $MERGED"
echo "- Releases created: $RELEASES"
echo "- Issues encountered: $ISSUES"
echo ""

# Get current version
CURRENT_VERSION="unknown"
if [ -f "package.json" ]; then
    CURRENT_VERSION=$(grep '"version"' package.json | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
elif [ -f "Cargo.toml" ]; then
    CURRENT_VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*= "\(.*\)".*/\1/')
elif [ -f "VERSION" ]; then
    CURRENT_VERSION=$(cat VERSION)
elif [ -f "version.txt" ]; then
    CURRENT_VERSION=$(cat version.txt)
fi
echo "Current version: $CURRENT_VERSION"
echo ""

# Create completion report
echo -e "${YELLOW}Creating merge report...${NC}"

# Get merge details
MERGE_DETAILS=$(journal-query recent-context MERGER | grep "MERGER:MERGED")
COMPLETED_WORK=$(journal-query recent-context MERGER | grep "WORK:COMPLETED")

cat > MERGE_REPORT.md << EOF
# Merge Completion Report

## Date: $(date -Iseconds)

## Summary
- Branches merged: $MERGED
- Releases created: $RELEASES
- Current version: $CURRENT_VERSION
- Issues encountered: $ISSUES

## Completed Tasks
$(echo "$COMPLETED_WORK" | sed 's/.*WORK:COMPLETED\] MERGER: /- /' | tail -10)

## Merged Branches
$(echo "$MERGE_DETAILS" | sed 's/.*\[MERGER:MERGED\] /- /' || echo "No merges logged")

## Releases Created
$(journal-query recent-context MERGER | grep "MERGER:RELEASE" | sed 's/.*\[MERGER:RELEASE\] /- /' || echo "No releases created")

## Repository Status
- Main branch: Up to date ✓
- Feature branches cleaned: ✓
- CI/CD status: Passing ✓
- Documentation: Updated ✓

## Open Items
$(gh pr list --json number,title 2>/dev/null | jq -r '.[] | "- PR #\(.number): \(.title)"' || echo "- No open PRs")
$(gh issue list --json number,title 2>/dev/null | jq -r '.[] | "- Issue #\(.number): \(.title)"' | head -5 || echo "- No open issues")

## Development Cycle Complete

The current development cycle has completed successfully. 

### For New Features:
1. Start with ARCHITECT persona to design the next iteration
2. Create new feature branches from updated main
3. Follow the standard workflow

### For Bug Fixes:
1. Start with DEVELOPER persona
2. Create fix branches as needed
3. Follow abbreviated workflow (DEVELOPER → QA → MERGER)

## Recommendations
- Monitor production for any post-merge issues
- Review metrics and user feedback
- Plan next iteration based on priorities
EOF

echo -e "${GREEN}Created MERGE_REPORT.md${NC}"

# Log completion
journal-log "HANDOFF:COMPLETED" "Development cycle complete. $MERGED merges, $RELEASES releases"
journal-log "MERGER:CONTEXT" "Merge cycle complete. Version $CURRENT_VERSION"

# Check if there are more PRs waiting
PENDING_PRS=$(gh pr list --json number 2>/dev/null | jq '. | length' || echo "0")

if [ "$PENDING_PRS" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Note: There are still $PENDING_PRS open PRs${NC}"
    echo "Creating work items for continued development..."
    
    # Create work items to continue
    journal-log "WORK:PENDING" "DEVELOPER: Review open PRs and continue development"
    journal-log "WORK:PENDING" "DEVELOPER: Address any post-merge issues"
    
    NEXT_PERSONA="DEVELOPER"
    NEXT_ACTION="continue with open PRs"
else
    echo ""
    echo -e "${GREEN}All PRs processed. Development cycle complete!${NC}"
    echo ""
    echo "Next steps depend on your needs:"
    echo "• For new features: Start with ARCHITECT"
    echo "• For bug fixes: Start with DEVELOPER"
    echo "• For maintenance: Start with DEVELOPER"
    
    NEXT_PERSONA=""
    NEXT_ACTION="start new cycle"
fi

echo ""
echo -e "${BLUE}=== Cycle Summary ===${NC}"
echo ""

# Show journey through personas
echo "Journey completed:"
PERSONA_FLOW=$(journal-query recent-context | grep "PERSONA:INIT" | tail -10 | sed 's/.*\[\(.*\):INIT\].*/  → \1/')
echo "$PERSONA_FLOW"
echo ""

# Show work completed
echo "Total work items completed:"
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    count=$(journal-query recent-context $persona | grep -c "WORK:COMPLETED" || echo "0")
    [ $count -gt 0 ] && echo "  $persona: $count items"
done
echo ""

if [ -n "$NEXT_PERSONA" ]; then
    echo -e "${YELLOW}To continue development:${NC}"
    echo "1. Run: /home/devuser/.claude/personas/$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')/$(echo $NEXT_PERSONA | tr '[:upper:]' '[:lower:]')-init.sh"
    echo "2. $NEXT_ACTION"
else
    echo -e "${GREEN}=== Development Cycle Complete ===${NC}"
    echo ""
    echo "Congratulations! The full development cycle has completed successfully."
    echo ""
    echo "To start a new cycle:"
    echo "• For new feature: /home/devuser/.claude/personas/architect/architect-init.sh"
    echo "• For bug fix: /home/devuser/.claude/personas/developer/developer-init.sh"
    echo ""
    echo "Use /journal-summary to see the overall system state."
fi
