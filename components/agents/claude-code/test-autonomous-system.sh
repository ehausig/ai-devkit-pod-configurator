#!/bin/bash
# Test script for the autonomous development system
# Run this after deployment to verify everything is working

set -e

echo "=== Autonomous Development System Test ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_item() {
    local description="$1"
    local command="$2"
    
    echo -n "Testing: $description... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test detailed
test_detailed() {
    local description="$1"
    local command="$2"
    
    echo -e "\n${YELLOW}Testing: $description${NC}"
    echo "Command: $command"
    echo "---"
    if eval "$command"; then
        echo -e "---\n${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "---\n${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "1. Checking environment setup..."
test_item "Claude Code installed" "command -v claude"
test_item "Bash available" "command -v bash"
test_item "Workspace directory exists" "[ -d ~/workspace ]"
test_item "Claude directory exists" "[ -d ~/.claude ]"

echo ""
echo "2. Checking files installation..."
test_item "Settings file exists" "[ -f ~/.claude/settings.json ]"
test_item "Orchestration hook exists" "[ -f ~/.claude/hooks/orchestrate.sh ]"
test_item "Orchestration hook is executable" "[ -x ~/.claude/hooks/orchestrate.sh ]"
test_item "Commands directory exists" "[ -d ~/.claude/commands ]"
test_item "Init-project command exists" "[ -f ~/.claude/commands/init-project.md ]"
test_item "Architect command exists" "[ -f ~/.claude/commands/architect.md ]"
test_item "Personas directory exists" "[ -d ~/.claude/personas ]"
test_item "Architect protocol exists" "[ -f ~/.claude/personas/ARCHITECT-PROTOCOL.md ]"

echo ""
echo "3. Testing orchestration hook..."
# Create minimal test input
cat > /tmp/test-hook-input.json << EOF
{
    "hook_event_name": "Stop",
    "session_id": "test-123",
    "stop_hook_active": false
}
EOF

# Test hook with no journal
test_item "Hook handles missing journal" "bash ~/.claude/hooks/orchestrate.sh < /tmp/test-hook-input.json"

# Create test journal
mkdir -p ~/workspace
cat > ~/workspace/JOURNAL.md << EOF
# Development Journal

## Events
2024-01-15T10:00:00Z | PROJECT_INIT | SYSTEM | Test project
2024-01-15T10:00:01Z | WORK_ASSIGNED | ARCHITECT | Design test system
EOF

# Test hook with pending work
echo ""
echo "Testing hook with pending work..."
OUTPUT=$(bash ~/.claude/hooks/orchestrate.sh < /tmp/test-hook-input.json 2>&1)
if echo "$OUTPUT" | grep -q '"decision": "block"'; then
    echo -e "${GREEN}PASS${NC} - Hook correctly identifies pending work"
    ((TESTS_PASSED++))
else
    echo -e "${RED}FAIL${NC} - Hook should block when work is pending"
    echo "Output: $OUTPUT"
    ((TESTS_FAILED++))
fi

# Add completion event
echo "2024-01-15T10:05:00Z | WORK_COMPLETE | ARCHITECT | Design test system" >> ~/workspace/JOURNAL.md
echo "2024-01-15T10:10:00Z | CYCLE_COMPLETE | MERGER | Test complete" >> ~/workspace/JOURNAL.md

# Test hook with completed work
echo "Testing hook with completed work..."
OUTPUT=$(bash ~/.claude/hooks/orchestrate.sh < /tmp/test-hook-input.json 2>&1)
if [ -z "$OUTPUT" ] || ! echo "$OUTPUT" | grep -q '"decision": "block"'; then
    echo -e "${GREEN}PASS${NC} - Hook correctly allows stop when cycle complete"
    ((TESTS_PASSED++))
else
    echo -e "${RED}FAIL${NC} - Hook should allow stop when cycle is complete"
    echo "Output: $OUTPUT"
    ((TESTS_FAILED++))
fi

# Clean up test files
rm -f /tmp/test-hook-input.json

echo ""
echo "4. Testing commands availability..."
# This would need to be run inside Claude Code
echo -e "${YELLOW}Note: Command tests need to be run inside Claude Code${NC}"
echo "After starting Claude Code, try:"
echo "  /init-project"
echo "  /show-journal"
echo "  /persona-status"

echo ""
echo "5. Testing journal operations..."
# Reset journal for testing
cat > ~/workspace/JOURNAL.md << EOF
# Development Journal

## Events
EOF

test_detailed "Event emission simulation" "echo '$(date -u +\"%Y-%m-%dT%H:%M:%SZ\") | TEST_EVENT | SYSTEM | Test event' >> ~/workspace/JOURNAL.md"
test_item "Journal has test event" "grep -q 'TEST_EVENT' ~/workspace/JOURNAL.md"

echo ""
echo "=== Test Summary ==="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed! The system appears to be correctly installed.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start Claude Code: claude"
    echo "2. Try: Please initiate the architect persona and create a hello world project in Python"
    echo "3. Monitor with: /show-journal"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. Please check the installation.${NC}"
    exit 1
fi
