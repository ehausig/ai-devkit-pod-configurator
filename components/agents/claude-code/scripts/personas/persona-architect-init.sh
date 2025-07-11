#!/bin/bash
# ARCHITECT Persona Initialization Script - ENHANCED for pure event sourcing

# Colors for output (only if running in terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
else
    GREEN=''
    YELLOW=''
    BLUE=''
    RED=''
    NC=''
fi

# Determine if running from hook context
HOOK_CONTEXT=""
if [ -n "$HOOK_TYPE" ] || [ -n "$JSON_INPUT" ]; then
    HOOK_CONTEXT="true"
fi

# Log initialization with transition complete event
es-journal-log.sh "ARCHITECT:INIT" "Starting ARCHITECT persona"
es-journal-log.sh "TRANSITION:COMPLETED" "ARCHITECT persona active"

# Safety check using journal query
SAFETY_STATUS=$(es-journal-query.sh safety-check ARCHITECT)
INIT_COUNT=$(echo "$SAFETY_STATUS" | grep -o "Iterations: [0-9]*" | cut -d' ' -f2)

if [ $INIT_COUNT -gt 10 ]; then
    if [ -n "$HOOK_CONTEXT" ]; then
        es-journal-log.sh "SAFETY:LIMIT" "ARCHITECT exceeded initialization limit: $INIT_COUNT"
        echo "ERROR: Safety limit exceeded - too many ARCHITECT initializations" >&2
        exit 1
    else
        echo -e "${RED}Safety limit exceeded: Too many ARCHITECT initializations${NC}"
        es-journal-log.sh "SAFETY:LIMIT" "ARCHITECT exceeded initialization limit: $INIT_COUNT"
        exit 1
    fi
fi

# Check for pending work using journal query
PENDING_WORK=$(es-journal-query.sh pending-work ARCHITECT)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] ARCHITECT: //')
    
    if [ -n "$HOOK_CONTEXT" ]; then
        # Hook context - minimal output
        es-journal-log.sh "ARCHITECT:CONTEXT" "Initialized with $PENDING_COUNT pending work items"
        
        # Prepare the first work item for execution
        es-work-tracker.sh prepare ARCHITECT >/dev/null 2>&1
        
        echo "ARCHITECT initialized with $PENDING_COUNT pending work items. First task: $FIRST_WORK"
        exit 0
    else
        # Interactive context - full output
        echo -e "${GREEN}Found $PENDING_COUNT pending work items:${NC}"
        echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] ARCHITECT: /    /'
        echo ""
    fi
else
    FIRST_WORK=""
    if [ -n "$HOOK_CONTEXT" ]; then
        echo "ARCHITECT initialized with no pending work items"
        exit 0
    fi
fi

# Rest of the script only runs in interactive mode
if [ -z "$HOOK_CONTEXT" ]; then
    # Check for recent handoffs
    echo -e "${YELLOW}Checking for handoffs...${NC}"
    RECENT_HANDOFF=$(es-journal-query.sh handoff-chain | grep "to ARCHITECT" | tail -1)
    if [ -n "$RECENT_HANDOFF" ]; then
        echo -e "${GREEN}Recent handoff:${NC}"
        echo "$RECENT_HANDOFF" | sed 's/.*\[HANDOFF:COMPLETED\] /  /'
        echo ""
    fi

    # Get context window
    echo -e "${YELLOW}Loading context...${NC}"
    es-context-window.sh ARCHITECT 20 | grep -E "(DECISION|MEMORY|HANDOFF)" | tail -10

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
        echo "You have $PENDING_COUNT pending work items. Your immediate task:"
        echo ""
        echo -e "${GREEN}→ $FIRST_WORK${NC}"
        echo ""
        echo "Action plan:"
        echo "1. Start this work item:"
        echo "   es-journal-log.sh 'WORK:STARTED' 'ARCHITECT: $FIRST_WORK'"
        echo ""
        echo "2. Complete the work and log decisions:"
        echo "   es-journal-log.sh 'ARCHITECT:DECISION' 'Decision description'"
        echo ""
        echo "3. When complete:"
        echo "   es-journal-log.sh 'WORK:COMPLETED' 'ARCHITECT: $FIRST_WORK'"
        echo ""
        echo "4. Continue with remaining items"
        echo "5. Run persona-architect-handoff.sh when all work is complete"
    elif [ ! -f "ARCHITECTURE.md" ]; then
        echo "Starting new project architecture. Please:"
        echo "1. Create ARCHITECTURE.md with system design"
        echo "2. Create API_DESIGN.md with API specifications"
        echo "3. Create DATA_MODELS.md with data structures"
        echo "4. Create TESTING_STRATEGY.md with test approach"
        echo "5. Log key decisions with: es-journal-log.sh 'ARCHITECT:DECISION' '[decision]'"
        echo "6. Run persona-architect-handoff.sh when complete"
    else
        echo "Design documents exist. Please:"
        echo "1. Review and update if needed"
        echo "2. Check for any new requirements"
        echo "3. Run persona-architect-handoff.sh to proceed"
    fi

    echo ""
    echo -e "${YELLOW}Remember to log all decisions:${NC}"
    echo 'es-journal-log.sh "ARCHITECT:DECISION" "Decision description"'
    echo 'es-journal-log.sh "ARCHITECT:MEMORY" "Critical constraint"'
    echo ""

    # Display helpful commands
    echo -e "${BLUE}Helpful commands:${NC}"
    echo "• View pending work: es-journal-query.sh pending-work ARCHITECT"
    echo "• Check decisions: es-journal-query.sh decisions ARCHITECT"
    echo "• View memories: es-journal-query.sh memory ARCHITECT"
    echo "• Check progress: es-journal-query.sh work-summary ARCHITECT"
    echo "• View context: es-context-window.sh ARCHITECT"
    echo ""

    # Display the full protocol inline if first time or explicitly requested
    if [ $PENDING_COUNT -eq 0 ] || [ "$1" = "--show-protocol" ]; then
        echo -e "${BLUE}=== ARCHITECT PROTOCOL ===${NC}"
        echo ""
        cat ~/.claude/personas/ARCHITECT-PROTOCOL.md
    fi
fi

# Log context understanding
es-journal-log.sh "ARCHITECT:CONTEXT" "Initialized with $PENDING_COUNT pending items"
