#!/bin/bash
# ARCHITECT Persona Handoff Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ARCHITECT Handoff Process ===${NC}"
echo ""

# Validate completion criteria
echo -e "${YELLOW}Validating completion criteria...${NC}"
READY=true

# Check for required design documents
for doc in ARCHITECTURE.md API_DESIGN.md DATA_MODELS.md TESTING_STRATEGY.md; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}✓${NC} $doc exists"
    else
        echo -e "${RED}✗${NC} $doc missing"
        READY=false
    fi
done

# Check for architectural decisions in journal
DECISIONS=$(grep -c "ARCHITECT:DECISION" ~/workspace/JOURNAL.md)
if [ "$DECISIONS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} $DECISIONS architectural decisions logged"
else
    echo -e "${RED}✗${NC} No architectural decisions logged"
    READY=false
fi

if [ "$READY" = false ]; then
    echo ""
    echo -e "${RED}ERROR: Not ready for handoff. Complete missing items first.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All criteria met. Proceeding with handoff...${NC}"
echo ""

# Summarize work completed
echo -e "${YELLOW}Summarizing completed work...${NC}"

# Count decisions and memories
DECISION_COUNT=$(grep -c "ARCHITECT:DECISION" ~/workspace/JOURNAL.md)
MEMORY_COUNT=$(grep -c "ARCHITECT:MEMORY" ~/workspace/JOURNAL.md)

echo "- Architectural decisions made: $DECISION_COUNT"
echo "- Critical constraints identified: $MEMORY_COUNT"
echo "- Design documents created: 4"
echo ""

# Extract key decisions for handoff
echo -e "${YELLOW}Key architectural decisions:${NC}"
grep "ARCHITECT:DECISION" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[ARCHITECT:DECISION\] /- /'
echo ""

# Extract critical memories
echo -e "${YELLOW}Critical constraints/requirements:${NC}"
grep "ARCHITECT:MEMORY" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[ARCHITECT:MEMORY\] /- /'
echo ""

# Log handoff
journal-log "ARCHITECT:CONTEXT" "Architecture phase complete. Design documents created, technology decisions made."
journal-log "ARCHITECT:HANDOFF" "Ready for DEVELOPER. Next: implement backend following design in feat/backend-api branch"

# Create handoff summary file
cat > HANDOFF_TO_DEVELOPER.md << EOF
# Handoff from ARCHITECT to DEVELOPER

## Date: $(date -Iseconds)

## Summary
The architecture phase is complete. All design documents have been created and technical decisions have been made.

## Key Decisions
$(grep "ARCHITECT:DECISION" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[ARCHITECT:DECISION\] /- /')

## Critical Constraints
$(grep "ARCHITECT:MEMORY" ~/workspace/JOURNAL.md | tail -5 | sed 's/.*\[ARCHITECT:MEMORY\] /- /')

## Design Documents
- ARCHITECTURE.md - System design and component overview
- API_DESIGN.md - API specifications
- DATA_MODELS.md - Data structures and schemas
- TESTING_STRATEGY.md - Testing approach

## Next Steps for DEVELOPER
1. Review all design documents
2. Create feature branch: feat/backend-api
3. Implement backend following TDD
4. Ensure all tests pass
5. Create PR when complete

## Implementation Priority
1. Core data models
2. API endpoints
3. Business logic
4. Error handling
5. Logging and monitoring
EOF

echo -e "${GREEN}Created HANDOFF_TO_DEVELOPER.md${NC}"
echo ""

# Display next steps
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. DEVELOPER should run: /home/devuser/.claude/personas/developer/developer-init.sh"
echo "2. DEVELOPER should review HANDOFF_TO_DEVELOPER.md"
echo "3. DEVELOPER should create feat/backend-api branch"
echo ""

# Auto-continue to next persona
echo -e "${GREEN}=== Auto-continuing to DEVELOPER persona ===${NC}"
echo ""
sleep 2  # Brief pause to let the output be visible
/home/devuser/.claude/personas/developer/developer-init.sh
