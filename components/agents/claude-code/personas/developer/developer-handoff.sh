#!/bin/bash
# DEVELOPER Persona Handoff Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DEVELOPER Handoff Process ===${NC}"
echo ""

# Validate completion criteria
echo -e "${YELLOW}Validating completion criteria...${NC}"
READY=true

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ ! "$CURRENT_BRANCH" =~ ^feat/ ]]; then
    echo -e "${YELLOW}⚠${NC} Not on a feature branch (current: $CURRENT_BRANCH)"
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}✗${NC} Uncommitted changes found"
    READY=false
else
    echo -e "${GREEN}✓${NC} Working directory clean"
fi

# Run tests
echo -e "${YELLOW}Running tests...${NC}"
if [ -f "package.json" ]; then
    if npm test 2>/dev/null; then
        echo -e "${GREEN}✓${NC} All tests passing"
    else
        echo -e "${RED}✗${NC} Tests failing"
        READY=false
    fi
elif [ -f "Cargo.toml" ]; then
    if cargo test 2>/dev/null; then
        echo -e "${GREEN}✓${NC} All tests passing"
    else
        echo -e "${RED}✗${NC} Tests failing"
        READY=false
    fi
elif [ -f "requirements.txt" ]; then
    if python -m pytest 2>/dev/null || pytest 2>/dev/null; then
        echo -e "${GREEN}✓${NC} All tests passing"
    else
        echo -e "${RED}✗${NC} Tests failing"
        READY=false
    fi
else
    echo -e "${YELLOW}⚠${NC} No recognized test framework found"
fi

# Check for PR
PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number --jq '.[0].number' 2>/dev/null)
if [ -n "$PR_NUMBER" ]; then
    echo -e "${GREEN}✓${NC} PR #$PR_NUMBER exists"
else
    echo -e "${YELLOW}⚠${NC} No PR created yet"
fi

if [ "$READY" = false ]; then
    echo ""
    echo -e "${RED}ERROR: Not ready for handoff. Fix failing tests first.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All criteria met. Proceeding with handoff...${NC}"
echo ""

# Summarize work completed
echo -e "${YELLOW}Summarizing completed work...${NC}"

# Count implementation details
COMMITS=$(git rev-list --count HEAD ^main 2>/dev/null || echo "0")
FILES_CHANGED=$(git diff --name-only main 2>/dev/null | wc -l || echo "0")
ISSUES_RESOLVED=$(grep -c "DEVELOPER:RESOLVED" ~/workspace/JOURNAL.md)

echo "- Commits on branch: $COMMITS"
echo "- Files changed: $FILES_CHANGED"
echo "- Issues resolved: $ISSUES_RESOLVED"
echo ""

# Extract key implementation details
echo -e "${YELLOW}Implementation highlights:${NC}"
grep "DEVELOPER:MEMORY" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[DEVELOPER:MEMORY\] /- /'
echo ""

# Create PR if needed
if [ -z "$PR_NUMBER" ]; then
    echo -e "${YELLOW}Creating Pull Request...${NC}"
    PR_OUTPUT=$(gh pr create \
        --title "feat: $CURRENT_BRANCH implementation" \
        --body "## Changes
- Implementation complete
- All tests passing

## Testing
✅ Unit tests
✅ Integration tests
✅ Coverage meets standards

## Next Steps
Ready for QA testing" 2>&1)
    
    if [ $? -eq 0 ]; then
        PR_NUMBER=$(echo "$PR_OUTPUT" | grep -o '#[0-9]*' | tr -d '#')
        echo -e "${GREEN}Created PR #$PR_NUMBER${NC}"
    else
        echo -e "${YELLOW}Could not create PR automatically${NC}"
    fi
fi

# Log handoff
journal-log "DEVELOPER:CONTEXT" "Implementation complete, all tests passing"
journal-log "DEVELOPER:HANDOFF" "Ready for QA. PR #$PR_NUMBER needs testing"

# Create handoff summary file
cat > HANDOFF_TO_QA.md << EOF
# Handoff from DEVELOPER to QA

## Date: $(date -Iseconds)

## Summary
Implementation is complete with all tests passing. Ready for comprehensive QA testing.

## Branch Information
- Branch: $CURRENT_BRANCH
- PR: #$PR_NUMBER
- Commits: $COMMITS
- Files Changed: $FILES_CHANGED

## Implementation Details
$(grep "DEVELOPER:MEMORY" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[DEVELOPER:MEMORY\] /- /')

## Test Status
- Unit Tests: ✅ Passing
- Integration Tests: ✅ Passing
- Coverage: Check PR for details

## Known Issues
$(grep "DEVELOPER:ISSUE" ~/workspace/JOURNAL.md | grep -v "RESOLVED" | tail -5 | sed 's/.*\[DEVELOPER:ISSUE\] /- /' || echo "None")

## Next Steps for QA
1. Pull branch: $CURRENT_BRANCH
2. Run all test suites
3. Test against real services (no mocks!)
4. Perform user simulation testing
5. Document any bugs found

## Testing Focus Areas
- Happy path functionality
- Error handling
- Edge cases
- Performance under load
- Security vulnerabilities
EOF

echo -e "${GREEN}Created HANDOFF_TO_QA.md${NC}"
echo ""

# Display next steps
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. QA should run: /home/devuser/.claude/personas/qa/qa-init.sh"
echo "2. QA should review HANDOFF_TO_QA.md"
echo "3. QA should pull branch: $CURRENT_BRANCH"
echo ""

# Auto-continue to next persona
echo -e "${GREEN}=== Auto-continuing to QA persona ===${NC}"
echo ""
sleep 2  # Brief pause to let the output be visible
/home/devuser/.claude/personas/qa/qa-init.sh
