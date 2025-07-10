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

# Log handoff request
es-journal-log.sh "HANDOFF:REQUEST" "ARCHITECT requesting handoff to DEVELOPER"

# Check for pending work first
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_CHECK=$(es-journal-query.sh handoff-ready ARCHITECT)
HANDOFF_READY=$?

if [ $HANDOFF_READY -ne 0 ]; then
    echo -e "${RED}$PENDING_CHECK${NC}"
    es-journal-log.sh "HANDOFF:BLOCKED" "ARCHITECT has pending work items"
    exit 1
fi

# Validate completion criteria
echo -e "${YELLOW}Validating completion criteria...${NC}"
READY=true
MISSING_ITEMS=""

# Check for required design documents
for doc in ARCHITECTURE.md API_DESIGN.md DATA_MODELS.md TESTING_STRATEGY.md; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}✓${NC} $doc exists"
    else
        echo -e "${RED}✗${NC} $doc missing"
        READY=false
        MISSING_ITEMS="$MISSING_ITEMS $doc"
    fi
done

# Check for architectural decisions in journal
DECISIONS=$(es-journal-query.sh decisions ARCHITECT | wc -l)
if [ "$DECISIONS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} $DECISIONS architectural decisions logged"
else
    echo -e "${RED}✗${NC} No architectural decisions logged"
    READY=false
    MISSING_ITEMS="$MISSING_ITEMS decisions"
fi

if [ "$READY" = false ]; then
    echo ""
    echo -e "${RED}ERROR: Not ready for handoff. Missing: $MISSING_ITEMS${NC}"
    es-journal-log.sh "HANDOFF:BLOCKED" "Missing requirements: $MISSING_ITEMS"
    exit 1
fi

# Validation passed
es-journal-log.sh "HANDOFF:VALIDATED" "All ARCHITECT requirements met"

echo ""
echo -e "${GREEN}All criteria met. Proceeding with handoff...${NC}"
echo ""

# Create work items for DEVELOPER
echo -e "${YELLOW}Creating work items for DEVELOPER...${NC}"

# Analyze design to create specific work items
if grep -q "backend" ARCHITECTURE.md 2>/dev/null || grep -q "API" API_DESIGN.md 2>/dev/null; then
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Create feature branch feat/backend-api"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Set up project structure with src/ and tests/ directories"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Write failing tests for core data models"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Implement data models to pass tests"
fi

if grep -q "REST\|HTTP" API_DESIGN.md 2>/dev/null; then
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Write failing tests for REST API endpoints"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Implement API endpoints to pass tests"
elif grep -q "GraphQL" API_DESIGN.md 2>/dev/null; then
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Write failing tests for GraphQL schema"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Implement GraphQL resolvers to pass tests"
fi

if grep -q "CLI\|command" ARCHITECTURE.md 2>/dev/null; then
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Write failing tests for CLI interface"
    es-journal-log.sh "WORK:PENDING" "DEVELOPER: Implement CLI commands to pass tests"
fi

# Always add these standard items
es-journal-log.sh "WORK:PENDING" "DEVELOPER: Ensure 80% test coverage minimum"
es-journal-log.sh "WORK:PENDING" "DEVELOPER: Add comprehensive error handling"
es-journal-log.sh "WORK:PENDING" "DEVELOPER: Create pull request when all tests pass"

# Count work items created
WORK_ITEMS=$(es-journal-query.sh pending-work DEVELOPER | wc -l)

# Summarize handoff
echo -e "${GREEN}Created $WORK_ITEMS work items for DEVELOPER${NC}"
echo ""

# Extract key information for handoff
echo -e "${YELLOW}Preparing handoff summary...${NC}"

# Get key decisions and memories
KEY_DECISIONS=$(es-journal-query.sh decisions ARCHITECT 5)
KEY_MEMORIES=$(es-journal-query.sh memory ARCHITECT 5)

# Create handoff summary file
cat > HANDOFF_TO_DEVELOPER.md << EOF
# Handoff from ARCHITECT to DEVELOPER

## Date: $(date -Iseconds)

## Summary
The architecture phase is complete. All design documents have been created and technical decisions have been made.

## Work Items Created
$(es-journal-query.sh pending-work DEVELOPER | sed 's/.*WORK:PENDING\] DEVELOPER: /- /')

## Key Architectural Decisions
$(echo "$KEY_DECISIONS" | sed 's/.*\[.*:DECISION\] /- /')

## Critical Constraints/Requirements
$(echo "$KEY_MEMORIES" | sed 's/.*\[.*:MEMORY\] /- /')

## Design Documents
- ARCHITECTURE.md - System design and component overview
- API_DESIGN.md - API specifications
- DATA_MODELS.md - Data structures and schemas
- TESTING_STRATEGY.md - Testing approach

## Development Guidelines
1. Follow TDD - write tests first
2. Create feature branches for each component
3. Ensure all tests pass before marking work complete
4. Maintain 80% code coverage minimum
5. Document any deviations from design

## Next Steps
1. Review this handoff document
2. Check pending work items in journal
3. Create feature branch
4. Start with first work item
EOF

echo -e "${GREEN}Created HANDOFF_TO_DEVELOPER.md${NC}"

# Complete handoff
es-journal-log.sh "HANDOFF:COMPLETED" "Handed off to DEVELOPER with $WORK_ITEMS work items"
es-journal-log.sh "ARCHITECT:CONTEXT" "Architecture phase complete. Design documents created, technology decisions made."

echo ""
echo -e "${BLUE}=== Handoff Complete ===${NC}"
echo ""
echo -e "${YELLOW}DEVELOPER should now:${NC}"
echo "1. Run: persona-developer-init.sh"
echo "2. Review pending work items"
echo "3. Start implementing with TDD approach"
echo ""

# Signal that work is ready for DEVELOPER
echo "DEVELOPER" > /tmp/persona-work-ready

echo -e "${GREEN}✓ Work queue signaled for DEVELOPER${NC}"
echo ""
echo "The work queue monitor will prepare the first executable task."
