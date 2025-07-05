#!/bin/bash
# ARCHITECT Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing ARCHITECT Persona ===${NC}"
echo ""

# Log initialization
journal-log.sh "ARCHITECT:INIT" "Starting ARCHITECT persona"

# Safety check using journal query
SAFETY_STATUS=$(journal-query.sh safety-check ARCHITECT)
INIT_COUNT=$(echo "$SAFETY_STATUS" | grep -o "Iterations: [0-9]*" | cut -d' ' -f2)

if [ $INIT_COUNT -gt 10 ]; then
    echo -e "${RED}Safety limit exceeded: Too many ARCHITECT initializations${NC}"
    journal-log.sh "SAFETY:LIMIT" "ARCHITECT exceeded initialization limit: $INIT_COUNT"
    exit 1
fi

# Check for pending work using journal query
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING_WORK=$(journal-query.sh pending-work ARCHITECT)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    echo -e "${GREEN}Found $PENDING_COUNT pending work items:${NC}"
    echo "$PENDING_WORK" | sed 's/.*WORK:PENDING\] ARCHITECT: /  - /' | head -10
    echo ""
fi

# Check for recent handoffs
echo -e "${YELLOW}Checking for handoffs...${NC}"
RECENT_HANDOFF=$(journal-query.sh handoff-chain | grep "to ARCHITECT" | tail -1)
if [ -n "$RECENT_HANDOFF" ]; then
    echo -e "${GREEN}Recent handoff:${NC}"
    echo "$RECENT_HANDOFF" | sed 's/.*\[HANDOFF:COMPLETED\] /  /'
    echo ""
fi

# Get context window
echo -e "${YELLOW}Loading context...${NC}"
get-context-window.sh ARCHITECT 20 | grep -E "(DECISION|MEMORY|HANDOFF)" | tail -10

# Check for handoff document
if [ -f "HANDOFF_TO_ARCHITECT.md" ]; then
    echo ""
    echo -e "${GREEN}Found handoff document${NC}"
    head -20 HANDOFF_TO_ARCHITECT.md
    echo "..."
fi

# Check current project state
echo -e "${YELLOW}Checking project state...${NC}"
if [ -d .git ]; then
    echo "Current branch: $(git branch --show-current)"
    echo "Repository status:"
    git status --short | head -5
else
    echo "No git repository found in current directory"
fi

# Look for existing design documents
echo -e "${YELLOW}Checking for design documents...${NC}"
for doc in ARCHITECTURE.md API_DESIGN.md DATA_MODELS.md TESTING_STRATEGY.md; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}Found:${NC} $doc"
    else
        echo -e "${YELLOW}Missing:${NC} $doc"
    fi
done
echo ""

# Display work instructions based on context
echo -e "${BLUE}=== ARCHITECT Work Instructions ===${NC}"
echo ""

if [ $PENDING_COUNT -gt 0 ]; then
    echo "You have pending work items. Please:"
    echo "1. Complete the pending items listed above"
    echo "2. Mark each as completed with: journal-log.sh 'WORK:COMPLETED' 'ARCHITECT: [work description]'"
    echo "3. Run architect-handoff.sh when all work is complete"
elif [ ! -f "ARCHITECTURE.md" ]; then
    echo "Starting new project architecture. Please:"
    echo "1. Create ARCHITECTURE.md with system design"
    echo "2. Create API_DESIGN.md with API specifications"
    echo "3. Create DATA_MODELS.md with data structures"
    echo "4. Create TESTING_STRATEGY.md with test approach"
    echo "5. Log key decisions with: journal-log.sh 'ARCHITECT:DECISION' '[decision]'"
    echo "6. Run architect-handoff.sh when complete"
else
    echo "Design documents exist. Please:"
    echo "1. Review and update if needed"
    echo "2. Check for any new requirements"
    echo "3. Run architect-handoff.sh to proceed"
fi

echo ""
echo -e "${YELLOW}Remember to log all decisions:${NC}"
echo 'journal-log.sh "ARCHITECT:DECISION" "Decision description"'
echo 'journal-log.sh "ARCHITECT:MEMORY" "Critical constraint"'
echo ""

# Log context understanding
journal-log.sh "ARCHITECT:CONTEXT" "Initialized with $PENDING_COUNT pending items"

# Display the full protocol inline
echo -e "${BLUE}=== ARCHITECT PROTOCOL ===${NC}"
echo ""
cat ~/.claude/personas/architect/ARCHITECT-PROTOCOL.md
