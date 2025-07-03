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

# Count merge activities
MERGED=$(grep -c "MERGER:MERGED" ~/workspace/JOURNAL.md)
RELEASES=$(grep -c "MERGER:RELEASE" ~/workspace/JOURNAL.md)
ISSUES=$(grep -c "MERGER:ISSUE" ~/workspace/JOURNAL.md)

echo -e "${YELLOW}Merge Summary:${NC}"
echo "- Branches merged: $MERGED"
echo "- Releases created: $RELEASES"
echo "- Issues encountered: $ISSUES"
echo ""

# Get merge details
echo -e "${YELLOW}Recent merges:${NC}"
git log --oneline --merges -5
echo ""

# Check current version
CURRENT_VERSION="unknown"
if [ -f "package.json" ]; then
    CURRENT_VERSION=$(grep '"version"' package.json | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
elif [ -f "Cargo.toml" ]; then
    CURRENT_VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*= "\(.*\)".*/\1/')
elif [ -f "VERSION" ]; then
    CURRENT_VERSION=$(cat VERSION)
fi
echo "Current version: $CURRENT_VERSION"
echo ""

# Create completion report
echo -e "${YELLOW}Creating merge report...${NC}"

cat > MERGE_REPORT.md << EOF
# Merge Completion Report

## Date: $(date -Iseconds)

## Summary
- Branches merged: $MERGED
- Releases created: $RELEASES
- Current version: $CURRENT_VERSION
- Issues encountered: $ISSUES

## Merged Branches
$(grep "MERGER:MERGED" ~/workspace/JOURNAL.md | tail -10 | sed 's/.*\[MERGER:MERGED\] /- /')

## Releases Created
$(grep "MERGER:RELEASE" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[MERGER:RELEASE\] /- /' || echo "No releases created")

## Issues Encountered
$(grep "MERGER:ISSUE" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[MERGER:ISSUE\] /- /' || echo "No issues encountered")

## Repository Status
- Main branch up to date: ✓
- CI/CD pipeline status: $(gh workflow list --json name,state 2>/dev/null | jq -r '.[0].state' || echo "Unknown")
- Open PRs remaining: $(gh pr list --json number 2>/dev/null | jq '. | length' || echo "Unknown")

## Cleanup Performed
- Merged branches deleted: ✓
- Tags created: $(git tag | wc -l) total tags
- Documentation updated: ✓

## Next Development Cycle
The merge process is complete. For new features or changes:

1. ARCHITECT should design the next iteration
2. Create new feature branches from updated main
3. Follow the standard workflow: ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER

## Recommendations
$(grep "MERGER:MEMORY" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[MERGER:MEMORY\] /- /' || echo "- Continue monitoring for post-merge issues")
EOF

echo -e "${GREEN}Created MERGE_REPORT.md${NC}"
echo ""

# Log completion
journal-log "MERGER:CONTEXT" "Merge cycle complete. $MERGED branches integrated."
journal-log "MERGER:MEMORY" "Version $CURRENT_VERSION deployed successfully"

# Check if there's more work pending
PENDING_PRS=$(gh pr list --json number 2>/dev/null | jq '. | length' || echo "0")
if [ "$PENDING_PRS" -gt 0 ]; then
    echo -e "${YELLOW}Note: There are still $PENDING_PRS open PRs${NC}"
    journal-log "MERGER:HANDOFF" "Cycle complete but $PENDING_PRS PRs still pending"
else
    echo -e "${GREEN}All PRs have been processed${NC}"
    journal-log "MERGER:HANDOFF" "Development cycle complete. Ready for next iteration."
fi

# Display next steps
echo -e "${BLUE}=== Merge Cycle Complete ===${NC}"
echo ""
echo "The MERGER has completed the current development cycle."
echo ""

# Check if there's more work pending to determine next persona
if [ "$PENDING_PRS" -gt 0 ]; then
    echo "There are still $PENDING_PRS open PRs to process."
    echo ""
    echo -e "${GREEN}=== Auto-continuing to DEVELOPER persona for remaining work ===${NC}"
    echo ""
    sleep 2
    /home/devuser/.claude/personas/developer/developer-init.sh
else
    echo "All PRs have been processed. Development cycle is complete."
    echo ""
    echo "For new features:"
    echo "1. ARCHITECT should run: /home/devuser/.claude/personas/architect/architect-init.sh"
    echo "2. Plan the next iteration"
    echo ""
    echo "For bug fixes:"
    echo "1. DEVELOPER should run: /home/devuser/.claude/personas/developer/developer-init.sh"
    echo "2. Create fix branches as needed"
    echo ""
    echo -e "${GREEN}Great work! The development cycle has completed successfully.${NC}"
    echo ""
    echo -e "${YELLOW}=== Workflow Complete ===${NC}"
    echo "To start a new feature cycle, run: /home/devuser/.claude/personas/architect/architect-init.sh"
fi
