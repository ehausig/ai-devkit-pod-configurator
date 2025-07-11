#!/bin/bash
# QA Persona Initialization Script
# Hook-compatible version

# Colors for output (only if running in terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    NC='\033[0m'
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

# Log initialization
es-journal-log.sh "QA:INIT" "Starting QA persona"

# Safety check
SAFETY_STATUS=$(es-journal-query.sh safety-check QA)
INIT_COUNT=$(echo "$SAFETY_STATUS" | grep -o "Iterations: [0-9]*" | cut -d' ' -f2)

if [ "$INIT_COUNT" -gt 10 ]; then
    if [ -n "$HOOK_CONTEXT" ]; then
        es-journal-log.sh "SAFETY:LIMIT" "QA exceeded initialization limit: $INIT_COUNT"
        echo "ERROR: Safety limit exceeded - too many QA initializations" >&2
        exit 1
    else
        echo -e "${RED}Safety limit exceeded${NC}"
        es-journal-log.sh "SAFETY:LIMIT" "QA exceeded safe iteration count"
        exit 1
    fi
fi

# Check for pending work
PENDING_WORK=$(es-journal-query.sh pending-work QA)
PENDING_COUNT=$(echo "$PENDING_WORK" | grep -c "WORK:PENDING" || echo "0")

if [ $PENDING_COUNT -gt 0 ]; then
    FIRST_WORK=$(echo "$PENDING_WORK" | head -1 | sed 's/.*WORK:PENDING\] QA: //')
    
    if [ -n "$HOOK_CONTEXT" ]; then
        # Hook context - minimal output
        es-journal-log.sh "QA:CONTEXT" "Initialized with $PENDING_COUNT pending test items"
        es-work-tracker.sh prepare QA >/dev/null 2>&1
        echo "QA initialized with $PENDING_COUNT pending test items. First task: $FIRST_WORK"
        exit 0
    else
        # Interactive context - full output
        echo -e "${GREEN}Found $PENDING_COUNT pending work items:${NC}"
        echo "$PENDING_WORK" | nl | sed 's/.*WORK:PENDING\] QA: /    /'
        echo ""
    fi
else
    FIRST_WORK=""
    if [ -n "$HOOK_CONTEXT" ]; then
        echo "QA initialized with no pending work items"
        exit 0
    fi
fi

# Rest of interactive-only content...
if [ -z "$HOOK_CONTEXT" ]; then
    # All the interactive display logic here
    # (Same pattern as DEVELOPER script)
    
    # Check for handoff document
    if [ -f "HANDOFF_TO_QA.md" ]; then
        echo -e "${GREEN}Found handoff document:${NC}"
        grep -E "^##|^- " HANDOFF_TO_QA.md | head -15
        echo ""
    fi
    
    # Load testing strategy
    echo -e "${YELLOW}Loading testing strategy...${NC}"
    if [ -f "TESTING_STRATEGY.md" ]; then
        echo -e "${GREEN}Testing strategy found${NC}"
        grep -E "^##|^###" TESTING_STRATEGY.md | head -10
    else
        echo -e "${YELLOW}No testing strategy document found${NC}"
    fi
    
    # Display full instructions, protocol, etc.
    # ... (rest of the original interactive content)
fi

# Log context
es-journal-log.sh "QA:CONTEXT" "Initialized with $PENDING_COUNT pending test items"
