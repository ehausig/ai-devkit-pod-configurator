---
description: Show current status of all personas
---

# Persona Status

Display the current status and workload of each persona.

## Usage

`/persona-status`

## Implementation

```bash
# Check if journal exists
if [ ! -f ~/workspace/JOURNAL.md ]; then
    echo "No journal found. Start a project with /init-project"
    exit 1
fi

echo "=== Persona Status Dashboard ==="
echo ""

# Check each persona
for PERSONA in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    echo "━━━ $PERSONA ━━━"
    
    # Count work items
    ASSIGNED=$(grep -c "WORK_ASSIGNED | $PERSONA" ~/workspace/JOURNAL.md 2>/dev/null || echo 0)
    STARTED=$(grep -c "WORK_STARTED | $PERSONA" ~/workspace/JOURNAL.md 2>/dev/null || echo 0)
    COMPLETE=$(grep -c "WORK_COMPLETE | $PERSONA" ~/workspace/JOURNAL.md 2>/dev/null || echo 0)
    PENDING=$((ASSIGNED - COMPLETE))
    
    # Determine status
    if [ $PENDING -gt 0 ]; then
        STATUS="🟡 ACTIVE - $PENDING pending tasks"
    elif [ $COMPLETE -gt 0 ]; then
        STATUS="🟢 COMPLETE - All tasks finished"
    else
        STATUS="⚪ IDLE - No work assigned"
    fi
    
    echo "Status: $STATUS"
    echo "Tasks: $ASSIGNED assigned, $STARTED started, $COMPLETE completed"
    
    # Show recent activity
    LAST_EVENT=$(grep " | $PERSONA | " ~/workspace/JOURNAL.md | tail -1)
    if [ -n "$LAST_EVENT" ]; then
        EVENT_TIME=$(echo "$LAST_EVENT" | cut -d' ' -f1)
        EVENT_TYPE=$(echo "$LAST_EVENT" | cut -d'|' -f2 | xargs)
        echo "Last activity: $EVENT_TYPE at $EVENT_TIME"
    fi
    
    # Show pending work details
    if [ $PENDING -gt 0 ]; then
        echo "Pending work:"
        grep "WORK_ASSIGNED | $PERSONA" ~/workspace/JOURNAL.md | while read -r line; do
            WORK_DESC=$(echo "$line" | cut -d'|' -f4- | xargs)
            # Check if this work is complete
            if ! grep -q "WORK_COMPLETE | $PERSONA | $WORK_DESC" ~/workspace/JOURNAL.md; then
                echo "  • $WORK_DESC"
            fi
        done
    fi
    
    # Show handoff status
    HANDOFFS_FROM=$(grep -c "HANDOFF | $PERSONA->" ~/workspace/JOURNAL.md 2>/dev/null || echo 0)
    HANDOFFS_TO=$(grep -c "->$PERSONA" ~/workspace/JOURNAL.md 2>/dev/null || echo 0)
    if [ $HANDOFFS_FROM -gt 0 ] || [ $HANDOFFS_TO -gt 0 ]; then
        echo "Handoffs: $HANDOFFS_TO received, $HANDOFFS_FROM given"
    fi
    
    echo ""
done

# Show workflow summary
echo "=== Workflow Summary ==="

# Current phase
if grep -q "CYCLE_COMPLETE" ~/workspace/JOURNAL.md; then
    echo "Phase: 🎉 COMPLETE - Development cycle finished"
else
    # Find active phase based on last activity
    LAST_ACTIVE=$(grep -E "WORK_STARTED|WORK_ASSIGNED" ~/workspace/JOURNAL.md | tail -1 | cut -d'|' -f3 | xargs)
    if [ -n "$LAST_ACTIVE" ]; then
        echo "Phase: $LAST_ACTIVE phase in progress"
    else
        echo "Phase: Waiting to start"
    fi
fi

# Show handoff flow
echo ""
echo "Handoff Flow:"
grep "HANDOFF |" ~/workspace/JOURNAL.md | tail -5 | while read -r line; do
    HANDOFF=$(echo "$line" | cut -d'|' -f3 | xargs)
    TIME=$(echo "$line" | cut -d' ' -f1)
    echo "  $TIME: $HANDOFF"
done

# Project metrics
echo ""
echo "=== Project Metrics ==="
DECISIONS=$(grep -c "DECISION |" ~/workspace/JOURNAL.md)
FILES_CREATED=$(grep -c "FILE_CREATED |" ~/workspace/JOURNAL.md)
TESTS_RUN=$(grep -c "TEST_RESULT |" ~/workspace/JOURNAL.md)
ISSUES_FOUND=$(grep -c -E "QA_ISSUE|REVIEW_ISSUE" ~/workspace/JOURNAL.md)

echo "Decisions made: $DECISIONS"
echo "Files created: $FILES_CREATED"
echo "Test runs: $TESTS_RUN"
echo "Issues found: $ISSUES_FOUND"

# Show test coverage if available
COVERAGE=$(grep "TEST_COVERAGE" ~/workspace/JOURNAL.md | tail -1 | grep -o "[0-9]*%")
if [ -n "$COVERAGE" ]; then
    echo "Test coverage: $COVERAGE"
fi
```

## Status Indicators

- 🟡 **ACTIVE** - Persona has pending work
- 🟢 **COMPLETE** - All assigned work finished
- ⚪ **IDLE** - No work assigned yet

## Display Sections

1. **Individual Persona Status**
   - Current state
   - Task counts
   - Pending work items
   - Last activity
   - Handoff statistics

2. **Workflow Summary**
   - Current development phase
   - Recent handoff flow

3. **Project Metrics**
   - Total decisions made
   - Files created
   - Tests executed
   - Issues discovered
   - Test coverage

## Notes

- Provides real-time view of development progress
- Shows which persona is currently active
- Helps identify bottlenecks in workflow
- Useful for monitoring autonomous development
