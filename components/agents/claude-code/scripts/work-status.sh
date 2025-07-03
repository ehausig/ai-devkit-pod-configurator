#!/bin/bash
# Check work status and next actions
# Usage: work-status.sh [persona]

PERSONA="${1:-$(journal-query current-persona)}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Work Status for $PERSONA ===${NC}"
echo ""

# Get pending work count
PENDING_COUNT=$(journal-query pending-work "$PERSONA" | wc -l)

# Get completed work in current session
RECENT_COMPLETED=$(journal-query recent-context "$PERSONA" | grep -c "WORK:COMPLETED" || echo "0")

# Check for work script
if [ -f /tmp/execute-next-work.sh ]; then
    WORK_READY="${GREEN}✓ Ready${NC}"
    WORK_SCRIPT="Yes"
else
    WORK_READY="${YELLOW}⚠ Not prepared${NC}"
    WORK_SCRIPT="No"
fi

# Display status
echo -e "Current Persona: ${CYAN}$PERSONA${NC}"
echo -e "Pending Work Items: ${YELLOW}$PENDING_COUNT${NC}"
echo -e "Recently Completed: ${GREEN}$RECENT_COMPLETED${NC}"
echo -e "Work Script Ready: $WORK_READY"
echo ""

# Show pending work items
if [ $PENDING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Pending Work Items:${NC}"
    journal-query pending-work "$PERSONA" | nl | sed 's/.*WORK:PENDING\] /    /'
    echo ""
fi

# Check for blocked work
BLOCKED_COUNT=$(journal-query recent-context "$PERSONA" | grep -c "WORK:BLOCKED" || echo "0")
if [ $BLOCKED_COUNT -gt 0 ]; then
    echo -e "${RED}⚠ Blocked Work Items:${NC}"
    journal-query recent-context "$PERSONA" | grep "WORK:BLOCKED" | tail -3 | sed 's/.*\[WORK:BLOCKED\] /  - /'
    echo ""
fi

# Show next actions
echo -e "${BLUE}Next Actions:${NC}"

if [ "$WORK_SCRIPT" = "Yes" ]; then
    echo "1. Execute prepared work: /tmp/execute-next-work.sh"
elif [ $PENDING_COUNT -gt 0 ]; then
    echo "1. Prepare work script: /home/devuser/.claude/hooks/prepare-next-work.sh $PERSONA"
    echo "2. Then execute: /tmp/execute-next-work.sh"
else
    echo "1. All work complete for $PERSONA"
    echo "2. Run handoff: /home/devuser/.claude/personas/$(echo $PERSONA | tr '[:upper:]' '[:lower:]')/$(echo $PERSONA | tr '[:upper:]' '[:lower:]')-handoff.sh"
fi

echo ""

# Check for handoff readiness
if [ $PENDING_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ Ready for handoff${NC}"
    
    # Suggest next persona based on current
    case "$PERSONA" in
        ARCHITECT)
            echo "Next persona: DEVELOPER"
            ;;
        DEVELOPER)
            echo "Next persona: QA"
            ;;
        QA)
            # Check if tests passed
            FAILED=$(journal-query recent-context QA | grep -c "QA:FAILED" || echo "0")
            if [ $FAILED -eq 0 ]; then
                echo "Next persona: REVIEWER (all tests passed)"
            else
                echo "Next persona: DEVELOPER (fixes needed)"
            fi
            ;;
        REVIEWER)
            # Check if approved
            ISSUES=$(journal-query recent-context REVIEWER | grep -c "REVIEWER:ISSUE" || echo "0")
            if [ $ISSUES -eq 0 ]; then
                echo "Next persona: MERGER (approved)"
            else
                echo "Next persona: DEVELOPER (changes requested)"
            fi
            ;;
        MERGER)
            echo "Cycle complete. Choose next action based on needs."
            ;;
    esac
fi

# Show recent errors if any
RECENT_ERRORS=$(journal-query errors "$PERSONA" 3)
if [ -n "$RECENT_ERRORS" ]; then
    echo ""
    echo -e "${RED}Recent Errors:${NC}"
    echo "$RECENT_ERRORS" | sed 's/.*\[\(.*\)\] /[\1] /'
fi
