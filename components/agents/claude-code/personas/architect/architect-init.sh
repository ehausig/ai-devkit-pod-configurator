#!/bin/bash
# ARCHITECT Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing ARCHITECT Persona ===${NC}"
echo ""

# Log initialization
journal-log "ARCHITECT:INIT" "Starting ARCHITECT persona"

# Check for pending handoffs
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING=$(grep "HANDOFF.*ARCHITECT" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$PENDING" ]; then
    echo -e "${GREEN}Found pending handoffs:${NC}"
    echo "$PENDING"
    echo ""
fi

# Reconstruct context from journal
echo -e "${YELLOW}Loading previous context...${NC}"

# Get recent architect activities
RECENT_CONTEXT=$(grep "\[ARCHITECT:" ~/workspace/JOURNAL.md | tail -20)
if [ -n "$RECENT_CONTEXT" ]; then
    echo -e "${GREEN}Recent ARCHITECT activities:${NC}"
    echo "$RECENT_CONTEXT" | tail -10
    echo ""
fi

# Get architectural decisions
DECISIONS=$(grep "ARCHITECT:DECISION" ~/workspace/JOURNAL.md | tail -10)
if [ -n "$DECISIONS" ]; then
    echo -e "${GREEN}Previous architectural decisions:${NC}"
    echo "$DECISIONS"
    echo ""
fi

# Get persistent memories
MEMORIES=$(grep "ARCHITECT:MEMORY" ~/workspace/JOURNAL.md | tail -10)
if [ -n "$MEMORIES" ]; then
    echo -e "${GREEN}Important constraints/requirements:${NC}"
    echo "$MEMORIES"
    echo ""
fi

# Check current project state
echo -e "${YELLOW}Checking project state...${NC}"
if [ -d .git ]; then
    echo "Current branch: $(git branch --show-current)"
    echo "Repository status:"
    git status --short
else
    echo "No git repository found in current directory"
fi
echo ""

# Look for existing design documents
echo -e "${YELLOW}Checking for existing design documents...${NC}"
for doc in ARCHITECTURE.md API_DESIGN.md DATA_MODELS.md TESTING_STRATEGY.md; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}Found:${NC} $doc"
    else
        echo -e "${YELLOW}Missing:${NC} $doc"
    fi
done
echo ""

# Log context understanding
journal-log "ARCHITECT:CONTEXT" "Initialized with context from journal"

# Create active persona context file for Claude to read
echo "Creating active persona context..."
cat > ~/.claude/ACTIVE_PERSONA.md << EOF
# Active Persona: ARCHITECT

You are currently operating as the ARCHITECT persona.

## Your Protocol
$(cat ~/.claude/personas/architect/ARCHITECT-PROTOCOL.md)

## Current Context
$(grep "\[ARCHITECT:" ~/workspace/JOURNAL.md | tail -20)

## Pending Work
$(grep "HANDOFF.*ARCHITECT" ~/workspace/JOURNAL.md | tail -5)
EOF

journal-log "ARCHITECT:CONTEXT" "Created ACTIVE_PERSONA.md for Claude reference"

# Display next steps
echo -e "${BLUE}=== ARCHITECT Persona Ready ===${NC}"
echo ""
echo "Next steps:"
echo "1. Review project requirements"
echo "2. Create/update design documents"
echo "3. Make architectural decisions"
echo "4. Plan implementation phases"
echo "5. Run architect-handoff.sh when complete"
echo ""
echo -e "${GREEN}📖 Read your full protocol: @~/.claude/ACTIVE_PERSONA.md${NC}"
echo ""

# Create prompt reminder
echo -e "${YELLOW}Remember to log all decisions:${NC}"
echo 'journal-log "ARCHITECT:DECISION" "Decision description"'
echo 'journal-log "ARCHITECT:MEMORY" "Critical constraint"'
echo ""
