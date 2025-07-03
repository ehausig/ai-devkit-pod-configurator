#!/bin/bash
# Persona System Test Script - Fixed Version
# Tests core functionality of the journal-based persona system

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AI DevKit Persona System Test (Fixed) ===${NC}"
echo ""

# Test 1: Check if all required scripts exist and are executable
echo -e "${YELLOW}Test 1: Checking script availability...${NC}"
SCRIPTS=(
    "/usr/local/bin/journal-log"
    "/usr/local/bin/journal-query"
    "/usr/local/bin/journal-stats"
    "/usr/local/bin/get-context-window"
    "/usr/local/bin/work-tracker"
    "/home/devuser/.claude/personas/architect/architect-init.sh"
    "/home/devuser/.claude/personas/architect/architect-handoff.sh"
    "/home/devuser/.claude/personas/developer/developer-init.sh"
    "/home/devuser/.claude/personas/developer/developer-handoff.sh"
    "/home/devuser/.claude/personas/qa/qa-init.sh"
    "/home/devuser/.claude/personas/qa/qa-handoff.sh"
    "/home/devuser/.claude/personas/reviewer/reviewer-init.sh"
    "/home/devuser/.claude/personas/reviewer/reviewer-handoff.sh"
    "/home/devuser/.claude/personas/merger/merger-init.sh"
    "/home/devuser/.claude/personas/merger/merger-handoff.sh"
)

ALL_GOOD=true
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo -e "${GREEN}✓${NC} $script"
    else
        echo -e "${RED}✗${NC} $script (missing or not executable)"
        ALL_GOOD=false
    fi
done
echo ""

# Test 2: Initialize journal
echo -e "${YELLOW}Test 2: Initializing journal...${NC}"
cd ~/workspace
if journal-log "SYSTEM:INIT" "Test suite started"; then
    echo -e "${GREEN}✓${NC} Journal initialized successfully"
else
    echo -e "${RED}✗${NC} Failed to initialize journal"
    ALL_GOOD=false
fi
echo ""

# Test 3: Test journal-query commands
echo -e "${YELLOW}Test 3: Testing journal query functionality...${NC}"
QUERIES=(
    "pending-work ARCHITECT"
    "recent-context ARCHITECT"
    "safety-check ARCHITECT"
    "decisions ARCHITECT"
    "memory ARCHITECT"
    "work-summary ARCHITECT"
    "current-persona"
    "handoff-chain"
)

for query in "${QUERIES[@]}"; do
    if journal-query $query >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} journal-query $query"
    else
        echo -e "${RED}✗${NC} journal-query $query failed"
        ALL_GOOD=false
    fi
done
echo ""

# Test 4: Test work item lifecycle
echo -e "${YELLOW}Test 4: Testing work item lifecycle...${NC}"
TEST_WORK="TEST: Validate persona system functionality"

# Create pending work
if journal-log "WORK:PENDING" "ARCHITECT: $TEST_WORK"; then
    echo -e "${GREEN}✓${NC} Created pending work item"
else
    echo -e "${RED}✗${NC} Failed to create work item"
    ALL_GOOD=false
fi

# Check if it appears in pending work
if journal-query pending-work ARCHITECT | grep -q "$TEST_WORK"; then
    echo -e "${GREEN}✓${NC} Work item appears in pending query"
else
    echo -e "${RED}✗${NC} Work item not found in pending query"
    ALL_GOOD=false
fi

# Start the work
if journal-log "WORK:STARTED" "ARCHITECT: $TEST_WORK"; then
    echo -e "${GREEN}✓${NC} Marked work as started"
else
    echo -e "${RED}✗${NC} Failed to mark work as started"
    ALL_GOOD=false
fi

# Complete the work
if journal-log "WORK:COMPLETED" "ARCHITECT: $TEST_WORK"; then
    echo -e "${GREEN}✓${NC} Marked work as completed"
else
    echo -e "${RED}✗${NC} Failed to mark work as completed"
    ALL_GOOD=false
fi

# Verify it's no longer pending
if ! journal-query pending-work ARCHITECT | grep -q "$TEST_WORK"; then
    echo -e "${GREEN}✓${NC} Completed work removed from pending"
else
    echo -e "${RED}✗${NC} Completed work still showing as pending"
    ALL_GOOD=false
fi
echo ""

# Test 5: Test persona initialization (without full workflow)
echo -e "${YELLOW}Test 5: Testing persona initialization...${NC}"
# We'll capture output but not execute the full workflow
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    init_script="/home/devuser/.claude/personas/$(echo $persona | tr '[:upper:]' '[:lower:]')/$(echo $persona | tr '[:upper:]' '[:lower:]')-init.sh"
    if [ -f "$init_script" ]; then
        # Just check if the script runs without error (show first 5 lines)
        if $init_script 2>&1 | head -5 | grep -q "Initializing.*Persona"; then
            echo -e "${GREEN}✓${NC} $persona init script runs"
        else
            echo -e "${RED}✗${NC} $persona init script failed"
            ALL_GOOD=false
        fi
    fi
done
echo ""

# Test 6: Test journal statistics
echo -e "${YELLOW}Test 6: Testing journal statistics...${NC}"
if journal-stats 1 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Journal statistics working"
    # Show summary
    journal-stats 1 | grep -E "(Total Events|Work Items)" | head -5
else
    echo -e "${RED}✗${NC} Journal statistics failed"
    ALL_GOOD=false
fi
echo ""

# Test 7: Test context window
echo -e "${YELLOW}Test 7: Testing context window...${NC}"
if get-context-window ARCHITECT 10 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Context window retrieval working"
else
    echo -e "${RED}✗${NC} Context window failed"
    ALL_GOOD=false
fi
echo ""

# Test 8: Test work tracker
echo -e "${YELLOW}Test 8: Testing work tracker...${NC}"
if work-tracker "TEST" ARCHITECT >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Work tracker functioning"
else
    echo -e "${RED}✗${NC} Work tracker failed"
    ALL_GOOD=false
fi
echo ""

# Test 9: Test handoff validation
echo -e "${YELLOW}Test 9: Testing handoff validation...${NC}"
# Create some test work items
journal-log "WORK:PENDING" "DEVELOPER: Test item 1"
journal-log "WORK:PENDING" "DEVELOPER: Test item 2"

# Check handoff readiness (should fail with pending items)
if journal-query handoff-ready DEVELOPER 2>&1 | grep -q "Not ready"; then
    echo -e "${GREEN}✓${NC} Handoff validation correctly detects pending work"
else
    echo -e "${RED}✗${NC} Handoff validation not working correctly"
    ALL_GOOD=false
fi

# Clean up test items
journal-log "WORK:COMPLETED" "DEVELOPER: Test item 1"
journal-log "WORK:COMPLETED" "DEVELOPER: Test item 2"
echo ""

# Test 10: Check hook scripts
echo -e "${YELLOW}Test 10: Checking hook scripts...${NC}"
HOOKS=(
    "/home/devuser/.claude/hooks/journal.sh"
    "/home/devuser/.claude/hooks/bash-logger.sh"
    "/home/devuser/.claude/hooks/session-tracker.sh"
    "/home/devuser/.claude/hooks/format-code.sh"
    "/home/devuser/.claude/hooks/notification.sh"
)

for hook in "${HOOKS[@]}"; do
    if [ -f "$hook" ] && [ -x "$hook" ]; then
        echo -e "${GREEN}✓${NC} $(basename $hook)"
    else
        echo -e "${RED}✗${NC} $(basename $hook) (missing or not executable)"
        ALL_GOOD=false
    fi
done
echo ""

# Final Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}All tests passed! The persona system appears to be properly installed.${NC}"
else
    echo -e "${RED}Some tests failed. Please check the errors above.${NC}"
fi
echo ""

# Show journal location and recent entries
echo -e "${YELLOW}Journal location:${NC} ~/workspace/JOURNAL.md"
echo -e "${YELLOW}Recent journal entries:${NC}"
tail -10 ~/workspace/JOURNAL.md 2>/dev/null || echo "No journal entries yet"
echo ""

# Cleanup message
echo -e "${BLUE}Test complete. The test work items have been created and completed in the journal.${NC}"
echo -e "${BLUE}You can view the full journal with: cat ~/workspace/JOURNAL.md${NC}"
