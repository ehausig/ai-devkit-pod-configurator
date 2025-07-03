#!/bin/bash
# DEVELOPER Persona Initialization Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Initializing DEVELOPER Persona ===${NC}"
echo ""

# Log initialization
journal-log "DEVELOPER:INIT" "Starting DEVELOPER persona"

# Check for pending handoffs
echo -e "${YELLOW}Checking for pending work...${NC}"
PENDING=$(grep "HANDOFF.*DEVELOPER" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$PENDING" ]; then
    echo -e "${GREEN}Found pending handoffs:${NC}"
    echo "$PENDING"
    echo ""
fi

# Check for handoff file
if [ -f "HANDOFF_TO_DEVELOPER.md" ]; then
    echo -e "${GREEN}Found handoff document:${NC}"
    head -20 HANDOFF_TO_DEVELOPER.md
    echo "..."
    echo ""
fi

# Reconstruct context from journal
echo -e "${YELLOW}Loading architectural context...${NC}"

# Get architectural decisions
ARCH_DECISIONS=$(grep "ARCHITECT:DECISION" ~/workspace/JOURNAL.md | tail -5)
if [ -n "$ARCH_DECISIONS" ]; then
    echo -e "${GREEN}Architectural decisions:${NC}"
    echo "$ARCH_DECISIONS" | sed 's/.*\[ARCHITECT:DECISION\] /- /'
    echo ""
fi

# Get recent developer activities
RECENT_DEV=$(grep "\[DEVELOPER:" ~/workspace/JOURNAL.md | tail -10)
if [ -n "$RECENT_DEV" ]; then
    echo -e "${GREEN}Recent DEVELOPER activities:${NC}"
    echo "$RECENT_DEV" | tail -5
    echo ""
fi

# Check for unresolved issues
UNRESOLVED=$(grep "DEVELOPER:ISSUE" ~/workspace/JOURNAL.md | grep -v "RESOLVED" | tail -5)
if [ -n "$UNRESOLVED" ]; then
    echo -e "${YELLOW}Unresolved issues:${NC}"
    echo "$UNRESOLVED" | sed 's/.*\[DEVELOPER:ISSUE\] /- /'
    echo ""
fi

# Check current project state
echo -e "${YELLOW}Checking project state...${NC}"
if [ -d .git ]; then
    CURRENT_BRANCH=$(git branch --show-current)
    echo "Current branch: $CURRENT_BRANCH"
    
    # Check for feature branches
    echo "Feature branches:"
    git branch -a | grep "feat/" || echo "No feature branches found"
    
    echo ""
    echo "Repository status:"
    git status --short
else
    echo "No git repository found in current directory"
fi
echo ""

# Check for existing code
echo -e "${YELLOW}Checking existing implementation...${NC}"
if [ -d "src" ] || [ -d "backend" ] || [ -d "frontend" ]; then
    echo "Found code directories:"
    ls -la | grep "^d" | grep -E "(src|backend|frontend|tests)"
else
    echo "No implementation directories found yet"
fi
echo ""

# Check test status
if [ -f "package.json" ] || [ -f "Cargo.toml" ] || [ -f "requirements.txt" ]; then
    echo -e "${YELLOW}Project type detected. Checking tests...${NC}"
    if [ -d "tests" ] || [ -d "test" ]; then
        echo -e "${GREEN}Test directory found${NC}"
    else
        echo -e "${YELLOW}No test directory found - remember TDD!${NC}"
    fi
fi
echo ""

# Log context understanding
journal-log "DEVELOPER:CONTEXT" "Initialized with architectural context"

# Display next steps
echo -e "${BLUE}=== DEVELOPER Persona Ready ===${NC}"
echo ""
echo "Next steps:"
echo "1. Review design documents (ARCHITECTURE.md, API_DESIGN.md)"
echo "2. Create feature branch if needed"
echo "3. Write failing tests FIRST (TDD)"
echo "4. Implement minimum code to pass tests"
echo "5. Refactor and repeat"
echo "6. Run developer-handoff.sh when complete"
echo ""

# Create prompt reminder
echo -e "${YELLOW}Remember to log all activities:${NC}"
echo 'journal-log "DEVELOPER:CONTEXT" "Working on: [feature]"'
echo 'journal-log "DEVELOPER:ISSUE" "Problem: [description]"'
echo 'journal-log "DEVELOPER:RESOLVED" "Fixed: [solution]"'
echo ""

# Display the full protocol inline
echo -e "${BLUE}=== DEVELOPER PROTOCOL ===${NC}"
echo ""
cat ~/.claude/personas/developer/DEVELOPER-PROTOCOL.md
echo ""
echo -e "${YELLOW}The above protocol defines your responsibilities as DEVELOPER.${NC}"
